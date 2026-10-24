package com.insurancefraud.claim.service.impl;

import com.insurancefraud.common.security.CurrentUserServiceImpl;
import com.insurancefraud.claim.dto.ClaimDetailResponseDto;
import com.insurancefraud.claim.dto.ClaimRequestDto;
import com.insurancefraud.claim.dto.ClaimSummaryResponseDto;
import com.insurancefraud.claim.dto.PaginatedClaimResponse;
import com.insurancefraud.entity.*;
import com.insurancefraud.enums.*;
import com.insurancefraud.common.exception.ResourceNotFoundException;
import com.insurancefraud.claim.repository.ClaimRepo;
import com.insurancefraud.claim.service.ClaimService;
import com.insurancefraud.outbox.repository.OutboxEventRepo;
import com.insurancefraud.util.PaginationUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import com.insurancefraud.policy.repository.PolicyRepo;
import org.modelmapper.ModelMapper;
import org.springframework.data.domain.Page;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.time.Year;
import java.util.List;

@Slf4j
@RequiredArgsConstructor
@Service
public class ClaimServiceImpl implements ClaimService {

    private final CurrentUserServiceImpl currentUserService;
    private final ClaimRepo claimRepo;
    private final PolicyRepo policyRepo;
    private final ModelMapper mapper;
    private final OutboxEventRepo outboxEventRepo;


    public String generateClaimNumber(String tenantCode, Long claimId) {
        int year = Year.now().getValue();
        return String.format("%s-%d-%05d", tenantCode, year, claimId);
    }

    @Transactional
    @Override
    public ClaimSummaryResponseDto createClaim(ClaimRequestDto requestDto) {

    if (requestDto.getIncidentDate() == null) {
        throw new IllegalArgumentException("Incident date cannot be null");
    }

    User user = currentUserService.getCurrentActiveUser();

    Tenant tenant = user.getTenant();

    // Verify user has an active policy before filing a claim
    Policy activePolicy = policyRepo.findFirstByUserAndPolicyStatusOrderByCreatedAtDesc(user, PolicyStatus.ACTIVE)
            .orElseThrow(() -> new IllegalStateException("No active insurance policy found. You must buy or activate an insurance policy before filing a claim."));

    Claim claim = mapper.map(requestDto, Claim.class);

    claim.setTenant(tenant);
    claim.setUser(user);
    claim.setPolicy(activePolicy);
    claim.setFraudStatus(FraudStatus.PENDING_ANALYSIS);
    claim.setClaimStatus(ClaimStatus.PENDING);
    claim.setClaimNumber("TEMP-" + System.currentTimeMillis() + "-" + java.util.UUID.randomUUID().toString().substring(0, 8));

    // First save - MySQL generates claimId
    claim = claimRepo.save(claim);

    // Now claimId is available
    claim.setClaimNumber(
            generateClaimNumber(tenant.getTenantCode(), claim.getClaimId())
    );

    // Second save - updates claimNumber
    claim = claimRepo.save(claim);

    log.info("Claim created with ID: {} and OutboxEvent queued", claim.getClaimId());
    return mapper.map(claim, ClaimSummaryResponseDto.class);
}
          
    @Override
    @Transactional(readOnly = true)
    public PaginatedClaimResponse getClaimsForCurrentUser(int pageNumber, int pageSize, ClaimSortField sortBy, String sortDir) {
        User user = currentUserService.getCurrentActiveUser();

        // Using pagination utility
        Pageable pageable = PaginationUtils.buildPageable(pageNumber, pageSize, sortBy, sortDir);

        Page<Claim> claimPages = claimRepo.findByUserAndIsDeletedFalse(user, pageable);

        List<ClaimSummaryResponseDto> dtoList =
                claimPages.getContent()
                        .stream()
                        .map(claim ->
                                mapper.map(
                                        claim,
                                        ClaimSummaryResponseDto.class
                                )
                        )
                        .toList();

        log.info("Retrieved {} claims for user {}", dtoList.size(), user.getEmail());
        PaginatedClaimResponse response = new PaginatedClaimResponse();
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
    public ClaimDetailResponseDto getClaimById(Long claimId) {
        User user = currentUserService.getCurrentActiveUser();

        Claim claim = claimRepo.findByUserAndClaimIdAndIsDeletedFalse(user, claimId)
                .orElseThrow(() -> new ResourceNotFoundException("Claim not found with ID: " + claimId));

        ClaimDetailResponseDto dto = mapper.map(claim, ClaimDetailResponseDto.class);
        dto.setDecisionNotes(claim.getDecisionNotes());
        dto.setCustomerName(claim.getUser().isDeleted() ? "Deleted User" : claim.getUser().getFullName());
        dto.setCustomerEmail(claim.getUser().getEmail());
        dto.setInvestigatorName(claim.getAssignedInvestigator() != null ? claim.getAssignedInvestigator().getFullName() : "Not Assigned");
        dto.setTenantCode(claim.getTenant().getTenantCode());

        populatePolicyDetails(dto, claim);
        return dto;
    }

    private void populatePolicyDetails(ClaimDetailResponseDto dto, Claim claim) {
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
    }

    @Transactional
    @Override
    public void submitClaim(Long claimId) {
        User user = currentUserService.getCurrentActiveUser();
        Claim claim = claimRepo.findByUserAndClaimIdAndIsDeletedFalse(user, claimId)
                .orElseThrow(() -> new ResourceNotFoundException("Claim not found with ID: " + claimId));

        // 1. Move claim status
        claim.setClaimStatus(ClaimStatus.PENDING);
        claim.setFraudStatus(FraudStatus.PENDING_ANALYSIS);
        claimRepo.save(claim);

        // 2. Build Outbox Event
        String payloadJson = String.format(
                "{\"claimId\": %d, \"claimNumber\": \"%s\", \"tenantId\": %d}",
                claim.getClaimId(),
                claim.getClaimNumber(),
                claim.getTenant().getTenantId()
        );

        OutboxEvent outboxEvent = new OutboxEvent();
        outboxEvent.setTenant(claim.getTenant());
        outboxEvent.setEventType(EventType.CLAIM_SUBMITTED);
        outboxEvent.setAggregateType(AggregateType.CLAIM);
        outboxEvent.setAggregateId(claim.getClaimId());
        outboxEvent.setPayload(payloadJson);
        outboxEvent.setStatus(OutboxStatus.NEW);
        outboxEvent.setAttempts(0);
        outboxEvent.setNextAttemptAt(Instant.now());

        outboxEventRepo.save(outboxEvent);

        log.info("Claim #{} submitted! Outbox event stored for RabbitMQ.", claim.getClaimNumber());
    }
}