package com.insurancefraud.admin.service.Impl;

import com.insurancefraud.admin.dto.*;
import com.insurancefraud.claim.dto.ClaimSummaryResponseDto;
import com.insurancefraud.admin.service.AdminClaimService;
import com.insurancefraud.common.exception.ResourceNotFoundException;
import com.insurancefraud.common.security.CurrentUserService;
import com.insurancefraud.entity.Claim;
import com.insurancefraud.enums.*;
import com.insurancefraud.util.PaginationUtils;
import org.modelmapper.ModelMapper;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.transaction.annotation.Transactional;
import com.insurancefraud.entity.User;
import com.insurancefraud.claim.repository.ClaimRepo;
import com.insurancefraud.repository.UserRepo;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import com.insurancefraud.document.repository.ClaimDocumentRepo;
import com.insurancefraud.storage.service.StorageService;
import com.insurancefraud.entity.ClaimDocument;
import com.insurancefraud.common.exception.FileStorageException;
import com.insurancefraud.entity.Policy;
import com.insurancefraud.enums.PolicyStatus;
import com.insurancefraud.policy.repository.PolicyRepo;
import com.insurancefraud.outbox.service.OutboxService;
import com.insurancefraud.entity.ClaimEvidenceFlag;
import com.insurancefraud.fraud.dto.AiAnalysisDto;
import com.insurancefraud.fraud.dto.AiFlagDto;

@Service
@Slf4j
public class AdminClaimServiceImpl implements AdminClaimService {

    private final CurrentUserService currentUserService;
    private final UserRepo userRepo;
    private final ModelMapper mapper;
    private final ClaimRepo claimRepo;
    private final ClaimDocumentRepo claimDocumentRepo;
    private final StorageService storageService;
    private final PolicyRepo policyRepo;
    private final OutboxService outboxService;
    private final com.insurancefraud.fraud.repository.ClaimEvidenceFlagRepo claimEvidenceFlagRepo;

    public AdminClaimServiceImpl(CurrentUserService currentUserService,UserRepo userRepo,ClaimRepo claimRepo,ModelMapper mapper, ClaimDocumentRepo claimDocumentRepo, StorageService storageService, PolicyRepo policyRepo, OutboxService outboxService, com.insurancefraud.fraud.repository.ClaimEvidenceFlagRepo claimEvidenceFlagRepo) {
        this.currentUserService = currentUserService;
        this.userRepo = userRepo;
        this.claimRepo =claimRepo;
        this.mapper =mapper;
        this.claimDocumentRepo = claimDocumentRepo;
        this.storageService = storageService;
        this.policyRepo = policyRepo;
        this.outboxService = outboxService;
        this.claimEvidenceFlagRepo = claimEvidenceFlagRepo;
    }

    @Override
    @Transactional
        public void assignInvestigatorToClaim(Long claimId, Long investigatorId) {
        User admin = currentUserService.getCurrentActiveUser();

        Claim claim = claimRepo.findByClaimIdAndTenantAndIsDeletedFalse(claimId, admin.getTenant())
                        .orElseThrow(() -> new ResourceNotFoundException("Claim not found"));

        User investigator =
                userRepo
                        .findByTenantAndRole_RoleCodeAndIsDeletedFalseAndStatusAndUserId(
                                admin.getTenant(),
                                RoleCode.INVESTIGATOR,
                                UserStatus.ACTIVE,
                                investigatorId
                        )
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Investigator not found"
                                )
                        );

        // PREVENT REASSIGNMENT
        if (claim.getAssignedInvestigator() != null) {
            throw new IllegalStateException(
                    "Claim already assigned to investigator"
            );
        }
        claim.setAssignedInvestigator(investigator);
        claim.setClaimStatus(ClaimStatus.UNDER_REVIEW);
        claimRepo.save(claim);

        outboxService.record(EventType.CLAIM_ASSIGNED, claim);

        log.info(
                "Admin {} assigned investigator {} to claim {}",
                admin.getEmail(),
                investigator.getEmail(),
                claim.getClaimNumber()
        );
    }

    @Override
    @Transactional(readOnly = true)
    public List<InvestigatorsWorkloadResDto> getInvestigatorsWorkload() {
        User admin = currentUserService.getCurrentActiveUser();

        List<User> investigators =
                userRepo
                        .findByTenantAndRole_RoleCodeAndIsDeletedFalseAndStatus(
                                admin.getTenant(),
                                RoleCode.INVESTIGATOR,
                                UserStatus.ACTIVE
                        );

        log.info(
                "Retrieved investigator workload for tenant {}",
                admin.getTenant().getTenantCode()
        );
        return investigators
                .stream().
                map(investigator -> {
                    Long activeClaims = claimRepo.
                            countByAssignedInvestigatorAndClaimStatusNotAndIsDeletedFalse(investigator, ClaimStatus.CLOSED);

                    Long reviewsCompleted = claimRepo.
                            countByAssignedInvestigatorAndFraudStatusNotAndIsDeletedFalse(investigator, FraudStatus.PENDING_ANALYSIS);

                    return new InvestigatorsWorkloadResDto(
                        investigator.getUserId(),
                        investigator.getFullName(),
                        investigator.getEmail(),
                        investigator.getStatus(),
                        reviewsCompleted,
                        activeClaims
                      );
                }
                ).toList();
    }

    @Transactional
    @Override
    public ClaimDecisionResponseDto approveClaim(Long claimId, ClaimDecisionRequestDto requestDto) {

        User admin = currentUserService.getCurrentActiveUser();

        Claim claim = claimRepo.findByClaimIdAndTenantAndIsDeletedFalse(claimId, admin.getTenant())
                        .orElseThrow(() -> new ResourceNotFoundException("Claim not found"));

        if (claim.getClaimStatus() == ClaimStatus.APPROVED) {
            throw new IllegalStateException("Claim already approved");
        }
        if (claim.getClaimStatus() == ClaimStatus.REJECTED) {
            throw new IllegalStateException("Claim already has a final decision");
        }
        if (claim.getClaimStatus() != ClaimStatus.UNDER_REVIEW) {
            throw new IllegalStateException("Claim must be under review before a decision can be made. Please assign an investigator first.");
        }
        if (claim.getFraudStatus() == FraudStatus.PENDING_ANALYSIS) {
            throw new IllegalStateException("Claim investigation not completed");
        }
        if (claim.getFraudStatus() == FraudStatus.CONFIRMED) {
            throw new IllegalStateException("Fraudulent claims cannot be approved");
        }

        claim.setDecisionNotes(requestDto.getDecisionNotes());
        claim.setClaimStatus(ClaimStatus.APPROVED);
        claim.setFraudStatus(FraudStatus.CLEAR);
        claimRepo.save(claim);

        outboxService.record(EventType.CLAIM_APPROVED, claim);

        log.info(
                "Admin {} approved claim {}",
                admin.getEmail(),
                claim.getClaimNumber()
        );
        return new ClaimDecisionResponseDto(
                claim.getClaimId(),
                claim.getClaimNumber(),
                claim.getClaimStatus(),
                claim.getDecisionNotes(),
                claim.getFraudStatus(),
                admin.getEmail(),
                claim.getUpdatedAt()
        );
    }

    @Transactional
    @Override
    public ClaimDecisionResponseDto rejectClaim(Long claimId, ClaimDecisionRequestDto requestDto) {
        User admin = currentUserService.getCurrentActiveUser();
        Claim claim = claimRepo.findByClaimIdAndTenantAndIsDeletedFalse(claimId, admin.getTenant())
                        .orElseThrow(() -> new ResourceNotFoundException("Claim not found"));

        if (claim.getClaimStatus() == ClaimStatus.REJECTED) {
            throw new IllegalStateException("Claim already rejected");
        }
        if (claim.getClaimStatus() == ClaimStatus.APPROVED) {
            throw new IllegalStateException("Claim already has a final decision");
        }
        if (claim.getClaimStatus() != ClaimStatus.UNDER_REVIEW) {
            throw new IllegalStateException("Claim must be under review before a decision can be made. Please assign an investigator first.");
        }
        if (claim.getFraudStatus() == FraudStatus.PENDING_ANALYSIS) {
            throw new IllegalStateException("Claim investigation not completed");
        }

        claim.setDecisionNotes(requestDto.getDecisionNotes());
        claim.setClaimStatus(ClaimStatus.REJECTED);
        claim.setFraudStatus(FraudStatus.CONFIRMED);
        claimRepo.save(claim);

        outboxService.record(EventType.CLAIM_REJECTED, claim);

        log.info(
                "Admin {} rejected claim {}",
                admin.getEmail(),
                claim.getClaimNumber()
        );

        return new ClaimDecisionResponseDto(
                claim.getClaimId(),
                claim.getClaimNumber(),
                claim.getClaimStatus(),
                claim.getDecisionNotes(),
                claim.getFraudStatus(),
                admin.getEmail(),
                claim.getUpdatedAt()
        );
    }

    @Transactional(readOnly = true)
    @Override
    public DashboardResponseDto getAdminDashboard() {
        User admin = currentUserService.getCurrentActiveUser();

        Long totalClaims = claimRepo.countByTenantAndIsDeletedFalse(admin.getTenant());
        Long pendingClaims = claimRepo.countByTenantAndClaimStatusAndIsDeletedFalse(admin.getTenant(), ClaimStatus.PENDING);
        Long underReviewClaims = claimRepo.countByTenantAndClaimStatusAndIsDeletedFalse(admin.getTenant(), ClaimStatus.UNDER_REVIEW);
        Long approvedClaims = claimRepo.countByTenantAndClaimStatusAndIsDeletedFalse(admin.getTenant(), ClaimStatus.APPROVED);
        Long rejectedClaims = claimRepo.countByTenantAndClaimStatusAndIsDeletedFalse(admin.getTenant(), ClaimStatus.REJECTED);
        Long suspectedFraudClaims = claimRepo.countByTenantAndFraudStatusAndIsDeletedFalse(admin.getTenant(), FraudStatus.SUSPECTED);
        Long confirmedFraudClaims = claimRepo.countByTenantAndFraudStatusAndIsDeletedFalse(admin.getTenant(), FraudStatus.CONFIRMED);
        Long clearClaims = claimRepo.countByTenantAndFraudStatusAndIsDeletedFalse(admin.getTenant(), FraudStatus.CLEAR);
        Long activeClaims =  pendingClaims + underReviewClaims;

        log.info(
                "Admin {} retrieved dashboard data for tenant {}",
                admin.getEmail(),
                admin.getTenant().getTenantCode()
        );

        return new DashboardResponseDto(
                totalClaims,
                pendingClaims,
                approvedClaims,
                rejectedClaims,
                suspectedFraudClaims,
                underReviewClaims,
                confirmedFraudClaims,
                clearClaims,
                activeClaims
        );
    }

    @Transactional(readOnly = true)
    @Override
    public List<AdminClaimSummaryResponseDto> getUnassignedClaimsForTenant() {
        User admin = currentUserService.getCurrentActiveUser();

        String tenantCode = admin.getTenant().getTenantCode();
        List<Claim> claims = claimRepo.findByTenant_TenantCodeAndIsDeletedFalseAndAssignedInvestigatorIsNull(tenantCode);

        log.info("Admin {} requested unassigned claims for tenant {}. Returning {} claims",
                admin.getEmail(), tenantCode, claims.size());

        return claims.stream().map(c -> {
            AdminClaimSummaryResponseDto dto = new AdminClaimSummaryResponseDto();
            dto.setClaimId(c.getClaimId());
            dto.setClaimNumber(c.getClaimNumber());
            dto.setClaimType(c.getClaimType());
            dto.setClaimAmount(c.getClaimAmount());
            dto.setClaimStatus(c.getClaimStatus());
            dto.setFraudStatus(c.getFraudStatus());
            dto.setFraudScore(c.getFraudScore());
            dto.setAiRiskLevel(c.getAiRiskLevel());
            dto.setIncidentDate(c.getIncidentDate());
            dto.setIncidentCity(c.getIncidentCity());
            dto.setCreatedAt(c.getCreatedAt());
            dto.setCustomerName(c.getUser() != null && !c.getUser().isDeleted() ? c.getUser().getFullName() : "Deleted User");
            dto.setCustomerEmail(c.getUser() != null ? c.getUser().getEmail() : null);
            dto.setInvestigatorName("Not Assigned");
            dto.setAiStatus(c.getAiStatus() != null ? c.getAiStatus().name() : (c.getFraudScore() != null ? "DONE" : "PENDING"));
            return dto;
        }).toList();
    }


    @Override
    @Transactional(readOnly = true)
    public PaginatedAdminClaimResponseDto getAllClaims(int pageNumber,int pageSize, ClaimSortField sortBy, String sortDir) {

        User admin = currentUserService.getCurrentActiveUser();

        // Using pagination utility
        Pageable pageable = PaginationUtils.buildPageable(pageNumber, pageSize, sortBy, sortDir);


        Page<Claim> claimPages =
                claimRepo.findByTenant_TenantCodeAndIsDeletedFalse(
                        admin.getTenant().getTenantCode(),
                        pageable
                );

        List<AdminClaimSummaryResponseDto> dtoList =
                claimPages.getContent()
                        .stream()
                        .map(claim -> {
                            AdminClaimSummaryResponseDto dto = new AdminClaimSummaryResponseDto();
                            dto.setClaimId(claim.getClaimId());
                            dto.setClaimNumber(claim.getClaimNumber());
                            dto.setClaimType(claim.getClaimType());
                            dto.setClaimAmount(claim.getClaimAmount());
                            dto.setClaimStatus(claim.getClaimStatus());
                            dto.setFraudStatus(claim.getFraudStatus());
                            dto.setFraudScore(claim.getFraudScore());
                            dto.setAiRiskLevel(claim.getAiRiskLevel());
                            dto.setIncidentDate(claim.getIncidentDate());
                            dto.setIncidentCity(claim.getIncidentCity());
                            dto.setDecisionNotes(claim.getDecisionNotes());
                            dto.setCreatedAt(claim.getCreatedAt());

                            dto.setCustomerName(
                                    claim.getUser().isDeleted()
                                            ? "Deleted User"
                                            : claim.getUser().getFullName()
                            );

                            dto.setCustomerEmail(
                                    claim.getUser().getEmail()
                            );

                            dto.setInvestigatorName(
                                    claim.getAssignedInvestigator() != null
                                            ? claim.getAssignedInvestigator().getFullName()
                                            : "Not Assigned"
                            );

                            dto.setAiStatus(
                                    claim.getAiStatus() != null
                                            ? claim.getAiStatus().name()
                                            : (claim.getFraudScore() != null ? "DONE" : "PENDING")
                            );

                            return dto;
                        })
                        .toList();

        log.info("Retrieved {} claims for admin {}", dtoList.size(), admin.getEmail());
        PaginatedAdminClaimResponseDto response = new PaginatedAdminClaimResponseDto();
        response.setContent(dtoList);
        response.setTotalElements(claimPages.getTotalElements());
        response.setTotalPages(claimPages.getTotalPages());
        response.setPageNo(claimPages.getNumber());
        response.setPageSize(claimPages.getSize());
        response.setFirst(claimPages.isFirst());
        response.setLast(claimPages.isLast());
        response.setSorted(claimPages.getSort().isSorted());
        response.setSortBy(sortBy.name());
        response.setNextPage(claimPages.hasNext() ? (long) claimPages.getNumber() + 1 : null);
        response.setPreviousPage(claimPages.hasPrevious() ? (long) claimPages.getNumber() - 1 : null);
        return response;
    }

    @Override
    @Transactional(readOnly = true)
    public AdminClaimDetailResponseDto getClaimById(Long claimId) {
        User admin = currentUserService.getCurrentActiveUser();
        Claim claim = claimRepo.findByClaimIdAndTenantAndIsDeletedFalse(claimId, admin.getTenant())
                .orElseThrow(() -> new ResourceNotFoundException("Claim not found"));

        AdminClaimDetailResponseDto dto = new AdminClaimDetailResponseDto();
        dto.setClaimId(claim.getClaimId());
        dto.setClaimNumber(claim.getClaimNumber());
        dto.setClaimType(claim.getClaimType());
        dto.setClaimAmount(claim.getClaimAmount());
        dto.setClaimStatus(claim.getClaimStatus());
        dto.setFraudStatus(claim.getFraudStatus());
        dto.setFraudScore(claim.getFraudScore());

        String aiStatusStr = claim.getAiStatus() != null ? claim.getAiStatus().name() : (claim.getFraudScore() != null ? "DONE" : "PENDING");
        dto.setAiStatus(aiStatusStr);
        dto.setAiRiskLevel(claim.getAiRiskLevel());
        dto.setAiRecommendation(claim.getAiRecommendation());
        dto.setAiSummary(claim.getAiSummary());

        List<ClaimEvidenceFlag> flags = claimEvidenceFlagRepo.findByClaim_ClaimId(claimId);
        List<AiFlagDto> flagDtos = flags.stream().map(f -> new AiFlagDto(
                f.getCode(),
                f.getCategory(),
                f.getSeverity() != null ? f.getSeverity().name() : "LOW",
                f.getExplanation(),
                f.getBenignExplanations(),
                f.getNextSteps(),
                f.getConfidence()
        )).toList();

        AiAnalysisDto aiAnalysis = new AiAnalysisDto(
                aiStatusStr,
                claim.getFraudScore(),
                claim.getAiRiskLevel(),
                claim.getAiRecommendation(),
                claim.getAiSummary(),
                claim.getAiAnalyzedAt(),
                flagDtos
        );
        dto.setAiAnalysis(aiAnalysis);

        dto.setDescription(claim.getDescription());
        dto.setIncidentDate(claim.getIncidentDate());
        dto.setIncidentAddress(claim.getIncidentAddress());
        dto.setIncidentCity(claim.getIncidentCity());
        dto.setIncidentState(claim.getIncidentState());
        dto.setReviewNotes(claim.getReviewNotes());
        dto.setDecisionNotes(claim.getDecisionNotes());

        dto.setCustomerName(claim.getUser().isDeleted() ? "Deleted User" : claim.getUser().getFullName());
        dto.setCustomerEmail(claim.getUser().getEmail());
        dto.setInvestigatorName(claim.getAssignedInvestigator() != null ? claim.getAssignedInvestigator().getFullName() : "Not Assigned");
        dto.setTenantCode(claim.getTenant().getTenantCode());
        dto.setCreatedAt(claim.getCreatedAt());
        dto.setUpdatedAt(claim.getUpdatedAt());

        Policy policy = claim.getPolicy();
        if (policy == null && claim.getUser() != null) {
            policy = policyRepo.findFirstByUserAndPolicyStatusOrderByCreatedAtDesc(claim.getUser(), PolicyStatus.ACTIVE).orElse(null);
        }
        if (policy != null) {
            dto.setPolicyNumber(policy.getPolicyNumber());
            dto.setPlanName(policy.getPolicyPlan() != null ? policy.getPolicyPlan().getPlanName() : "Vehicle Insurance Policy");
            dto.setVehicleNumber(policy.getVehicleNumber());
            dto.setVehicleMakeModel(policy.getVehicleMakeModel());
            dto.setInsuredDeclaredValue(policy.getInsuredDeclaredValue());
            dto.setPolicyStartDate(policy.getPolicyStartDate());
            dto.setPolicyEndDate(policy.getPolicyEndDate());
            dto.setPolicyStatus(policy.getPolicyStatus() != null ? policy.getPolicyStatus().name() : "ACTIVE");
        }

        return dto;
    }

    @Override
    @Transactional(readOnly = true)
    public List<com.insurancefraud.document.dto.ClaimDocumentsResponseDto> getClaimDocuments(Long claimId) {
        User admin = currentUserService.getCurrentActiveUser();
        
        Claim claim = claimRepo.findByClaimIdAndTenantAndIsDeletedFalse(claimId, admin.getTenant())
                .orElseThrow(() -> new ResourceNotFoundException("Claim not found"));

        List<ClaimDocument> claimDocuments = claimDocumentRepo.findByClaim_ClaimIdAndTenantAndIsDeletedFalse(claimId, admin.getTenant());

        return claimDocuments.stream()
                .map(doc -> mapper.map(doc, com.insurancefraud.document.dto.ClaimDocumentsResponseDto.class))
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public org.springframework.core.io.Resource downloadDocument(Long documentId) {
        User admin = currentUserService.getCurrentActiveUser();
        ClaimDocument document = claimDocumentRepo
                .findByClaimDocIdAndTenantAndIsDeletedFalse(documentId, admin.getTenant())
                .orElseThrow(() -> new ResourceNotFoundException("Document not found with ID: " + documentId));

        org.springframework.core.io.Resource resource;
        try {
            resource = storageService.downloadFile(document.getFileUrl());
        } catch (Exception e) {
            log.error("File download failed: {}", e.getMessage());
            throw new FileStorageException("Failed to download file", e);
        }
        log.info("Document {} downloaded by admin {}", document.getOriginalFileName(), admin.getEmail());
        return resource;
    }

    @Override
    @Transactional(readOnly = true)
    public ClaimDocument getClaimDocumentById(Long documentId) {
        User admin = currentUserService.getCurrentActiveUser();
        return claimDocumentRepo
                .findByClaimDocIdAndTenantAndIsDeletedFalse(documentId, admin.getTenant())
                .orElseThrow(() -> new ResourceNotFoundException("Document not found with ID: " + documentId));
    }

    @Override
    @Transactional
    public void rerunAiAnalysis(Long claimId) {
        User admin = currentUserService.getCurrentActiveUser();
        Claim claim = claimRepo.findByClaimIdAndTenantAndIsDeletedFalse(claimId, admin.getTenant())
                .orElseThrow(() -> new ResourceNotFoundException("Claim not found"));

        if (claim.getAiStatus() == AiStatus.RUNNING) {
            throw new IllegalStateException("AI analysis is already running for claim " + claim.getClaimNumber());
        }

        claim.setAiStatus(AiStatus.PENDING);
        claimRepo.save(claim);

        outboxService.record(EventType.AI_ANALYSIS_RERUN_REQUESTED, claim);

        log.info("Admin {} requested AI analysis rerun for claim {}", admin.getEmail(), claim.getClaimNumber());
    }
}

