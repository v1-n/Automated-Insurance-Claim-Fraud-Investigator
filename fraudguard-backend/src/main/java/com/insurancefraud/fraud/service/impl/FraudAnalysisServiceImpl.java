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
import com.insurancefraud.fraud.AiAnalysisClient;
import com.insurancefraud.fraud.dto.*;
import com.insurancefraud.fraud.repository.ClaimEvidenceFlagRepo;
import com.insurancefraud.fraud.service.FraudAnalysisService;
import com.insurancefraud.policy.repository.PolicyRepo;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
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

    @Override
    @Transactional
    public AnalyzeClaimResponseDto analyzeClaimAsync(Long claimId) {
        User user = currentUserService.getCurrentActiveUser();

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
        List<String> historicalHashes = claimDocumentRepo.findHistoricalPhashesByTenantId(claim.getTenant().getTenantId());

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

        // 6. Call Python AI Microservice
        log.info("Dispatching claim #{} to Python AI service with {} docs and {} photos",
                claim.getClaimNumber(), documents.size(), photos.size());
        AnalyzeClaimResponseDto response = aiAnalysisClient.dispatchToAi(requestDto);

        // 7. Persist Results in Database
        persistAiAnalysisResults(claim, allDocs, response);

        return response;
    }

    private void persistAiAnalysisResults(Claim claim, List<ClaimDocument> allDocs, AnalyzeClaimResponseDto response) {
        // Update Claim fraud score and status
        claim.setFraudScore(BigDecimal.valueOf(response.getRisk_score()));

        if (response.getRisk_score() < 25) {
            claim.setFraudStatus(FraudStatus.CLEAR);
        } else if (response.getRisk_score() >= 60) {
            claim.setFraudStatus(FraudStatus.SUSPECTED);
        } else {
            claim.setFraudStatus(FraudStatus.SUSPECTED);
        }

        claim.setAiRecommendation(response.getRecommendation());
        claim.setAiRiskLevel(response.getRisk_level() != null ? response.getRisk_level().name() : null);
        claim.setAiSummary(response.getSummary());
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

        // Save evidence flags
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
                entity.setConfidence(f.getConfidence());
                return entity;
            }).toList();
            claimEvidenceFlagRepo.saveAll(flagEntities);
        }

        log.info("Successfully persisted AI analysis for Claim #{} (Score: {}, Recommendation: {})",
                claim.getClaimNumber(), response.getRisk_score(), response.getRecommendation());
    }
}