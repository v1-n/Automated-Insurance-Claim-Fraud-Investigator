package com.insurancefraud.policy.service.impl;

import com.insurancefraud.common.exception.ResourceNotFoundException;
import com.insurancefraud.common.security.CurrentUserServiceImpl;
import com.insurancefraud.entity.Policy;
import com.insurancefraud.entity.PolicyPlan;
import com.insurancefraud.entity.Tenant;
import com.insurancefraud.entity.User;
import com.insurancefraud.enums.PolicyStatus;
import com.insurancefraud.enums.PolicyType;
import com.insurancefraud.policy.dto.CustomerSelectPolicyDto;
import com.insurancefraud.policy.dto.PolicyPlanResponseDto;
import com.insurancefraud.policy.dto.PolicyResponseDto;
import com.insurancefraud.policy.repository.PolicyPlanRepo;
import com.insurancefraud.policy.repository.PolicyRepo;
import com.insurancefraud.policy.service.CustomerPolicyService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.modelmapper.ModelMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.Year;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class CustomerPolicyServiceImpl implements CustomerPolicyService {

    private final CurrentUserServiceImpl currentUserService;
    private final PolicyPlanRepo policyPlanRepo;
    private final PolicyRepo policyRepo;
    private final ModelMapper mapper;

    public String generatePolicyNumber(String tenantCode, Long policyId) {
        int year = Year.now().getValue();
        return String.format("POL-%s-%d-%05d", tenantCode, year, policyId);
    }

    @Override
    @Transactional(readOnly = true)
    public List<PolicyPlanResponseDto> getAvailablePlans() {
        User user = currentUserService.getCurrentActiveUser();
        Tenant tenant = user.getTenant();

        return policyPlanRepo.findByTenantAndIsActiveTrue(tenant).stream()
                .map(plan -> mapper.map(plan, PolicyPlanResponseDto.class))
                .toList();
    }

    @Override
    @Transactional
    public PolicyResponseDto selectAndActivatePolicy(CustomerSelectPolicyDto requestDto) {
        User user = currentUserService.getCurrentActiveUser();
        Tenant tenant = user.getTenant();

        PolicyPlan plan = policyPlanRepo.findById(requestDto.getPlanId())
                .orElseThrow(() -> new ResourceNotFoundException("Policy Plan not found with ID: " + requestDto.getPlanId()));

        // Prevent duplicate purchase of the same plan
        if (policyRepo.existsByUserAndPolicyPlanAndPolicyStatus(user, plan, PolicyStatus.ACTIVE)) {
            throw new IllegalStateException("You already have an active policy for this plan: " + plan.getPlanName());
        }

        Policy policy = new Policy();
        policy.setTenant(tenant);
        policy.setUser(user);
        policy.setPolicyPlan(plan);
        policy.setVehicleNumber(requestDto.getVehicleNumber());
        policy.setVehicleMakeModel(requestDto.getVehicleMakeModel());
        policy.setInsuredDeclaredValue(plan.getMaxIdvCoverage());
        policy.setPolicyStatus(PolicyStatus.ACTIVE);
        policy.setPolicyStartDate(Instant.now());
        policy.setPolicyEndDate(Instant.now().plus(365, ChronoUnit.DAYS));

        // Temporary policy number before DB ID generation
        policy.setPolicyNumber("TEMP-" + System.currentTimeMillis());
        policy = policyRepo.save(policy);

        // Update real policy number
        policy.setPolicyNumber(generatePolicyNumber(tenant.getTenantCode(), policy.getPolicyId()));
        policy = policyRepo.save(policy);

        log.info("Customer {} activated policy {} for vehicle {}", user.getEmail(), policy.getPolicyNumber(), policy.getVehicleNumber());

        return mapToPolicyResponseDto(policy);
    }

    @Override
    @Transactional(readOnly = true)
    public List<PolicyResponseDto> getMyPolicies() {
        User user = currentUserService.getCurrentActiveUser();

        return policyRepo.findByUser(user).stream()
                .map(this::mapToPolicyResponseDto)
                .toList();
    }

    private PolicyResponseDto mapToPolicyResponseDto(Policy policy) {
        PolicyResponseDto dto = new PolicyResponseDto();
        dto.setPolicyId(policy.getPolicyId());
        dto.setPolicyNumber(policy.getPolicyNumber());
        dto.setPlanName(policy.getPolicyPlan() != null ? policy.getPolicyPlan().getPlanName() : "Custom Vehicle Policy");
        dto.setPolicyType(policy.getPolicyPlan() != null ? policy.getPolicyPlan().getPolicyType() : PolicyType.MOTOR_COMPREHENSIVE);
        dto.setVehicleNumber(policy.getVehicleNumber());
        dto.setVehicleMakeModel(policy.getVehicleMakeModel());
        dto.setInsuredDeclaredValue(policy.getInsuredDeclaredValue());
        dto.setPolicyStatus(policy.getPolicyStatus());
        dto.setPolicyStartDate(policy.getPolicyStartDate());
        dto.setPolicyEndDate(policy.getPolicyEndDate());
        dto.setUserName(policy.getUser().getFullName());
        dto.setUserEmail(policy.getUser().getEmail());
        dto.setTenantCode(policy.getTenant().getTenantCode());
        return dto;
    }
}
