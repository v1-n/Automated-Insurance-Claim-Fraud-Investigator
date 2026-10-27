package com.insurancefraud.fraud.service.impl;

import com.insurancefraud.claim.repository.ClaimRepo;
import com.insurancefraud.common.exception.ResourceNotFoundException;
import com.insurancefraud.document.repository.ClaimDocumentRepo;
import com.insurancefraud.entity.Claim;
import com.insurancefraud.entity.ClaimDocument;
import com.insurancefraud.entity.ClaimEvidenceFlag;
import com.insurancefraud.enums.AiStatus;
import com.insurancefraud.fraud.dto.AnalyzeClaimResponseDto;
import com.insurancefraud.fraud.dto.PhotoHashResultDto;
import com.insurancefraud.fraud.repository.ClaimEvidenceFlagRepo;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class AnalysisResultWriter {

    private final ClaimRepo claimRepo;
    private final ClaimDocumentRepo claimDocumentRepo;
    private final ClaimEvidenceFlagRepo claimEvidenceFlagRepo;

    @Transactional
    public void persistResults(Long claimId, AnalyzeClaimResponseDto response) {
        Claim claim = claimRepo.findByClaimIdAndIsDeletedFalse(claimId)
                .orElseThrow(() -> new ResourceNotFoundException("Claim not found with ID: " + claimId));

        List<ClaimDocument> allDocs = claimDocumentRepo.findByClaim_ClaimIdAndIsDeletedFalse(claimId);

        // Update Claim fraud score, aiStatus and AI advisory fields (AI is advisory: fraudStatus is reserved for investigator decision)
        claim.setFraudScore(BigDecimal.valueOf(response.getRisk_score()));
        claim.setAiRecommendation(response.getRecommendation());
        claim.setAiRiskLevel(response.getRisk_level() != null ? response.getRisk_level().name() : null);
        claim.setAiSummary(response.getSummary());
        claim.setAiStatus(AiStatus.DONE);
        claim.setAiAnalyzedAt(Instant.now());
        claimRepo.save(claim);

        // Save computed pHashes back to ClaimDocuments
        if (response.getDetails() != null && response.getDetails().getPhotoHashes() != null) {
            for (PhotoHashResultDto hashDto : response.getDetails().getPhotoHashes()) {
                allDocs.stream()
                        .filter(d -> d.getClaimDocId().equals(hashDto.getClaimDocId()))
                        .findFirst()
                        .ifPresent(doc -> {
                            doc.setPhash(hashDto.getPhash());
                            claimDocumentRepo.save(doc);
                        });
            }
        }

        // Save evidence flags with benign explanations and next steps
        claimEvidenceFlagRepo.deleteByClaim_ClaimId(claim.getClaimId());
        if (response.getFlags() != null) {
            List<ClaimEvidenceFlag> flagEntities = response.getFlags().stream().map(f -> {
                ClaimEvidenceFlag entity = new ClaimEvidenceFlag();
                entity.setClaim(claim);
                entity.setFlagId(f.getFlagId());
                entity.setCode(f.getCode());
                entity.setCategory(f.getCategory());
                entity.setSeverity(f.getSeverity());
                entity.setSource(f.getSource());
                entity.setExplanation(f.getExplanation());
                entity.setBenignExplanations(f.getBenignExplanations());
                entity.setNextSteps(f.getNextSteps());
                entity.setConfidence(f.getConfidence());
                return entity;
            }).toList();
            claimEvidenceFlagRepo.saveAll(flagEntities);
        }

        log.info("Successfully persisted AI analysis for Claim #{} (Score: {}, Recommendation: {}, Status: DONE)",
                claim.getClaimNumber(), response.getRisk_score(), response.getRecommendation());
    }
}
