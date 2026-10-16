package com.insurancefraud.investigator.service.impl;

import com.insurancefraud.claim.repository.ClaimRepo;
import com.insurancefraud.common.exception.ResourceNotFoundException;
import com.insurancefraud.common.security.CurrentUserService;
import com.insurancefraud.document.repository.ClaimDocumentRepo;
import com.insurancefraud.entity.Claim;
import com.insurancefraud.entity.User;
import com.insurancefraud.enums.ClaimSortField;
import com.insurancefraud.enums.ClaimStatus;
import com.insurancefraud.enums.FraudStatus;
import com.insurancefraud.investigator.dto.*;
import com.insurancefraud.util.PaginationUtils;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.transaction.annotation.Transactional;
import com.insurancefraud.investigator.service.InvestigatorClaimService;

import com.insurancefraud.entity.Policy;
import com.insurancefraud.enums.PolicyStatus;
import com.insurancefraud.policy.repository.PolicyRepo;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
@Slf4j
public class InvestigatorClaimServiceImpl implements InvestigatorClaimService {

    private final CurrentUserService currentUserService;
    private final ClaimRepo claimRepo;
    private final ClaimDocumentRepo claimDocumentRepo;
    private final PolicyRepo policyRepo;


    public InvestigatorClaimServiceImpl(CurrentUserService currentUserService, ClaimRepo claimRepo, ClaimDocumentRepo claimDocumentRepo, PolicyRepo policyRepo) {
        this.currentUserService = currentUserService;
        this.claimRepo = claimRepo;
        this.claimDocumentRepo = claimDocumentRepo;
        this.policyRepo = policyRepo;
    }


    @Override
    @Transactional(readOnly = true)
    public PaginatedInvestigatorClaimResponseDto getAssignedClaimsForInvestigator(
            int pageNumber,
            int pageSize,
            ClaimSortField sortBy,
            String sortDir
    ) {

        User investigator = currentUserService.getCurrentActiveUser();

        // Using pagination utility
        Pageable pageable = PaginationUtils.buildPageable(pageNumber, pageSize, sortBy, sortDir);

        Page<Claim> claimPages =
                claimRepo.findByAssignedInvestigatorAndIsDeletedFalse(
                        investigator,
                        pageable
                );

        List<InvestigatorClaimResponseDto> dtoList =
                claimPages.getContent()
                        .stream()
                        .map(claim ->
                                new InvestigatorClaimResponseDto(
                                        claim.getClaimId(),
                                        claim.getClaimNumber(),
                                        claim.getClaimType(),
                                        claim.getClaimAmount(),
                                        claim.getClaimStatus(),
                                        claim.getFraudStatus(),
                                        claim.getCreatedAt(),
                                        claim.getIncidentDate(),
                                        claim.getIncidentCity(),
                                        claim.getUser().isDeleted()
                                                ? "Deleted User"
                                                : claim.getUser().getFullName()
                                )
                        )
                        .toList();

        log.info(
                "INVESTIGATOR : Found {} claims assigned to investigator {}",
                dtoList.size(),
                investigator.getEmail()
        );

        PaginatedInvestigatorClaimResponseDto response =
                new PaginatedInvestigatorClaimResponseDto();

        response.setContent(dtoList);
        response.setTotalElements(claimPages.getTotalElements());
        response.setTotalPages(claimPages.getTotalPages());
        response.setPageNo(claimPages.getNumber());
        response.setPageSize(claimPages.getSize());
        response.setFirst(claimPages.isFirst());
        response.setLast(claimPages.isLast());
        response.setSorted(claimPages.getSort().isSorted());
        response.setSortBy(sortBy.name());

        response.setNextPage(
                claimPages.hasNext()
                        ? (long) claimPages.getNumber() + 1
                        : null
        );

        response.setPreviousPage(
                claimPages.hasPrevious()
                        ? (long) claimPages.getNumber() - 1
                        : null
        );

        return response;
    }

    @Override
    @Transactional(readOnly = true)
    public InvestigatorClaimDetailsResponseDto getClaimDetails(Long claimId) {
        User investigator = currentUserService.getCurrentActiveUser();

        Claim claim = claimRepo.findByClaimIdAndAssignedInvestigatorAndIsDeletedFalse(claimId, investigator)
                        .orElseThrow(() -> new ResourceNotFoundException("Claim not found"));

        List<ClaimDocumentResponseDto> documents =
                claimDocumentRepo
                        .findByClaim_ClaimIdAndIsDeletedFalse(claimId)
                        .stream()
                        .map(doc ->
                                new ClaimDocumentResponseDto(
                                        doc.getClaimDocId(),
                                        doc.getFileName(),
                                        doc.getDocumentType().name()
                                )
                        )
                        .toList();

        InvestigatorClaimDetailsResponseDto dto =
                new InvestigatorClaimDetailsResponseDto();

        dto.setReviewAllowed(
                claim.getClaimStatus() == ClaimStatus.UNDER_REVIEW && claim.getFraudStatus() == FraudStatus.PENDING_ANALYSIS
        );

        dto.setClaimId(claim.getClaimId());
        dto.setClaimNumber(claim.getClaimNumber());
        dto.setClaimType(claim.getClaimType());
        dto.setClaimAmount(claim.getClaimAmount());
        dto.setClaimStatus(claim.getClaimStatus());
        dto.setFraudStatus(claim.getFraudStatus());
        dto.setIncidentDate(claim.getIncidentDate());
        dto.setIncidentCity(claim.getIncidentCity());
        dto.setIncidentState(claim.getIncidentState());
        dto.setDescription(claim.getDescription());
        dto.setCustomerId(claim.getUser().getUserId());
        dto.setCustomerName(claim.getUser().isDeleted()
                ? "Deleted User"
                : claim.getUser().getFullName());
        dto.setCustomerEmail(claim.getUser().getEmail());
        dto.setDocuments(documents);
        dto.setUpdatedAt(claim.getUpdatedAt());
        dto.setReviewNotes(claim.getReviewNotes());
        dto.setCreatedAt(claim.getCreatedAt());

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

    @Transactional
    @Override
    public InvestigatorClaimReviewResponseDto reviewClaimById(Long claimId, InvestigatorClaimReviewRequestDto requestDto) {

        User investigator = currentUserService.getCurrentActiveUser();

        Claim claim = claimRepo
                .findByClaimIdAndAssignedInvestigatorAndClaimStatusAndIsDeletedFalse(claimId, investigator, ClaimStatus.UNDER_REVIEW)
                        .orElseThrow(() -> new ResourceNotFoundException("Claim not found or not assigned"));

        if (claim.getFraudStatus() != FraudStatus.PENDING_ANALYSIS) {
            log.warn("Claim {} already reviewed by investigator {}", claim.getClaimNumber(), investigator.getEmail());
            throw new IllegalStateException("Claim already reviewed");
        }

        claim.setReviewNotes(requestDto.getReviewNotes());
        claim.setFraudStatus(requestDto.getFraudStatus());
        claimRepo.save(claim);
        log.info(
                "Investigator {} reviewed claim {}",
                investigator.getEmail(),
                claim.getClaimNumber()
        );

        return new InvestigatorClaimReviewResponseDto(
                claim.getClaimId(),
                claim.getClaimNumber(),
                claim.getClaimStatus(),
                claim.getFraudStatus(),
                claim.getReviewNotes(),
                investigator.getFullName(),
                claim.getUpdatedAt()
        );
    }
}
