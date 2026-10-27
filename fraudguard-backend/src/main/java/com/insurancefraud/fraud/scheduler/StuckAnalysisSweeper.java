package com.insurancefraud.fraud.scheduler;

import com.insurancefraud.claim.repository.ClaimRepo;
import com.insurancefraud.entity.Claim;
import com.insurancefraud.enums.AiStatus;
import com.insurancefraud.enums.AnalysisRunStatus;
import com.insurancefraud.enums.EventType;
import com.insurancefraud.fraud.repository.ClaimAnalysisRunRepo;
import com.insurancefraud.outbox.service.OutboxService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class StuckAnalysisSweeper {

    private final ClaimRepo claimRepo;
    private final ClaimAnalysisRunRepo claimAnalysisRunRepo;
    private final OutboxService outboxService;

    @Scheduled(fixedDelay = 60000)
    @Transactional
    public void sweepStuckAnalyses() {
        Instant cutoff = Instant.now().minus(10, ChronoUnit.MINUTES);
        List<Claim> stuckClaims = claimRepo.findByAiStatusAndUpdatedAtBeforeAndIsDeletedFalse(AiStatus.RUNNING, cutoff);

        if (stuckClaims.isEmpty()) {
            return;
        }

        log.info("Found {} stuck AI analyses older than 10 minutes. Sweeping to FAILED...", stuckClaims.size());

        for (Claim claim : stuckClaims) {
            try {
                if (claim.getAiStatus() != AiStatus.DONE) {
                    claim.setAiStatus(AiStatus.FAILED);
                    claimRepo.save(claim);

                    claimAnalysisRunRepo.findFirstByClaim_ClaimIdAndStatusOrderByRunIdDesc(
                            claim.getClaimId(),
                            AnalysisRunStatus.STARTED
                    ).ifPresent(run -> {
                        run.setStatus(AnalysisRunStatus.FAILED);
                        run.setErrorMessage("AI analysis timed out after 10 minutes");
                        run.setCompletedAt(Instant.now());
                        claimAnalysisRunRepo.save(run);
                    });

                    outboxService.record(EventType.AI_ANALYSIS_FAILED, claim);
                    log.warn("Swept stuck AI analysis for Claim #{} (marked FAILED).", claim.getClaimNumber());
                }
            } catch (Exception ex) {
                log.error("Failed to sweep stuck analysis for Claim #{}: {}", claim.getClaimNumber(), ex.getMessage(), ex);
            }
        }
    }
}
