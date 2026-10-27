package com.insurancefraud.fraud.service.impl;

import com.insurancefraud.claim.repository.ClaimRepo;
import com.insurancefraud.common.exception.ResourceNotFoundException;
import com.insurancefraud.common.security.CurrentUserService;
import com.insurancefraud.document.repository.ClaimDocumentRepo;
import com.insurancefraud.entity.Claim;
import com.insurancefraud.entity.ClaimDocument;
import com.insurancefraud.entity.ClaimEvidenceFlag;
import com.insurancefraud.entity.Policy;
import com.insurancefraud.entity.User;
import com.insurancefraud.enums.DocumentType;
import com.insurancefraud.enums.FraudStatus;
import com.insurancefraud.enums.PolicyStatus;
import com.insurancefraud.fraud.client.AiAnalysisClient;
import com.insurancefraud.fraud.dto.*;
import com.insurancefraud.fraud.repository.ClaimEvidenceFlagRepo;
import com.insurancefraud.fraud.service.FraudAnalysisService;
import com.insurancefraud.entity.ClaimAnalysisRun;
import com.insurancefraud.enums.AnalysisRunStatus;
import com.insurancefraud.fraud.repository.ClaimAnalysisRunRepo;
import com.insurancefraud.policy.repository.PolicyRepo;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class FraudAnalysisServiceImpl implements FraudAnalysisService {

    private final AiAnalysisClient aiAnalysisClient;
    private final ClaimRepo claimRepo;
    private final ClaimDocumentRepo claimDocumentRepo;
    private final PolicyRepo policyRepo;
    private final ClaimEvidenceFlagRepo claimEvidenceFlagRepo;
    private final CurrentUserService currentUserService;
    private final AnalysisResultWriter analysisResultWriter;
    private final ClaimAnalysisRunRepo claimAnalysisRunRepo;

    @Override
    public AnalyzeClaimResponseDto analyzeClaimAsync(Long claimId) {
        return analyzeClaimAsync(claimId, null, "MANUAL");
    }

    @Override
    public AnalyzeClaimResponseDto analyzeClaimAsync(Long claimId, Long outboxEventId, String triggerType) {
        Claim claim = claimRepo.findByClaimIdAndIsDeletedFalse(claimId)
                .orElseThrow(() -> new ResourceNotFoundException("Claim not found with ID: " + claimId));

        int nextVersion = claimAnalysisRunRepo.findLatestRunVersion(claimId) + 1;

        ClaimAnalysisRun run = new ClaimAnalysisRun();
        run.setTenant(claim.getTenant());
        run.setClaim(claim);
        run.setRunVersion(nextVersion);
        run.setOutboxEventId(outboxEventId);
        run.setTriggerType(triggerType != null ? triggerType : "UNKNOWN");
        run.setStatus(AnalysisRunStatus.STARTED);
        run.setStartedAt(Instant.now());
        run = claimAnalysisRunRepo.save(run);

        AnalyzeClaimResponseDto response;
        try {
            AnalyzeClaimRequestDto requestDto = buildRequestDto(claimId);

            // HTTP call happens outside any DB transaction
            response = aiAnalysisClient.dispatchToAi(requestDto);

            // Mark run as COMPLETED with results
            run.setStatus(AnalysisRunStatus.COMPLETED);
            run.setCompletedAt(Instant.now());
            run.setRiskScore(BigDecimal.valueOf(response.getRisk_score()));
            run.setRecommendation(response.getRecommendation());
            claimAnalysisRunRepo.save(run);

            // Proxied transactional write via separate bean
            analysisResultWriter.persistResults(claimId, response);
            return response;
        } catch (Exception ex) {
            run.setStatus(AnalysisRunStatus.FAILED);
            run.setCompletedAt(Instant.now());
            String errorMsg = ex.getMessage() != null ? ex.getMessage() : ex.getClass().getSimpleName();
            run.setErrorMessage(errorMsg.substring(0, Math.min(errorMsg.length(), 1000)));
            claimAnalysisRunRepo.save(run);
            log.error("AI Analysis Run #{} failed for Claim #{}: {}", nextVersion, claim.getClaimNumber(), errorMsg);
            throw ex;
        }
    }

    public AnalyzeClaimRequestDto buildRequestDto(Long claimId){
        // 1. Fetch Claim
        Claim claim = claimRepo.findByClaimIdAndIsDeletedFalse(claimId)
                .orElseThrow(() -> new ResourceNotFoundException("Claim not found with ID: " + claimId));

        // 2. Fetch Associated Policy directly from the claim
        Policy policy = claim.getPolicy();
        if (policy == null) {
            policy = policyRepo.findFirstByUserAndPolicyStatusOrderByCreatedAtDesc(claim.getUser(), PolicyStatus.ACTIVE)
                    .orElseThrow(() -> new ResourceNotFoundException("Active Policy not found for claim ID: " + claimId));
        }

        // 3. Build Ground Truth
        ClaimGroundTruth groundTruth = new ClaimGroundTruth(
                policy.getVehicleNumber(),
                policy.getPolicyNumber(),
                policy.getPolicyStartDate() != null ? policy.getPolicyStartDate().toString() : null,
                policy.getPolicyEndDate() != null ? policy.getPolicyEndDate().toString() : null,
                policy.getInsuredDeclaredValue(),
                claim.getIncidentDate() != null ? claim.getIncidentDate().toString() : null,
                claim.getIncidentCity(),
                claim.getIncidentState(),
                null, // Latitude if stored on claim
                null  // Longitude if stored on claim
        );

        // 4. Fetch Claim Documents and Photos
        List<ClaimDocument> allDocs = claimDocumentRepo.findByClaim_ClaimIdAndIsDeletedFalse(claimId);
        List<String> historicalHashes = claimDocumentRepo.findHistoricalPhashesByTenantIdExcludingClaim(claim.getTenant().getTenantId(), claimId);

        List<DocumentPayload> documents = new ArrayList<>();
        List<PhotoPayload> photos = new ArrayList<>();

        for (ClaimDocument doc : allDocs) {
            if (doc.getDocumentType() == DocumentType.ACCIDENT_PHOTO) {
                photos.add(new PhotoPayload(doc.getClaimDocId(), doc.getFileUrl(), historicalHashes));
            } else {
                documents.add(new DocumentPayload(doc.getClaimDocId(), doc.getDocumentType(), doc.getFileUrl()));
            }
        }

        // 5. Construct AI Request DTO
        AnalyzeClaimRequestDto requestDto = new AnalyzeClaimRequestDto();
        requestDto.setTenantId(claim.getTenant().getTenantId());
        requestDto.setClaimId(claim.getClaimId());
        requestDto.setClaimNumber(claim.getClaimNumber());
        requestDto.setClaimAmount(claim.getClaimAmount());
        requestDto.setClaimGroundTruth(groundTruth);
        requestDto.setDocuments(documents);
        requestDto.setPhotos(photos);
        return requestDto;
    }
}