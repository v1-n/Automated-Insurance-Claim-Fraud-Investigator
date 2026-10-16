package com.insurancefraud.policy.service.impl;

import com.insurancefraud.common.exception.ResourceNotFoundException;
import com.insurancefraud.common.security.CurrentUserServiceImpl;
import com.insurancefraud.entity.Policy;
import com.insurancefraud.entity.PolicyPlan;
import com.insurancefraud.entity.Tenant;
import com.insurancefraud.entity.User;
import com.insurancefraud.enums.PolicyStatus;
import com.insurancefraud.enums.PolicyType;
import com.insurancefraud.policy.dto.AdminIssuePolicyDto;
import com.insurancefraud.policy.dto.PolicyPlanRequestDto;
import com.insurancefraud.policy.dto.PolicyPlanResponseDto;
import com.insurancefraud.policy.dto.PolicyResponseDto;
import com.insurancefraud.policy.repository.PolicyPlanRepo;
import com.insurancefraud.policy.repository.PolicyRepo;
import com.insurancefraud.policy.service.AdminPolicyService;
import com.insurancefraud.repository.UserRepo;
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
public class AdminPolicyServiceImpl implements AdminPolicyService {

    private final CurrentUserServiceImpl currentUserService;
    private final PolicyPlanRepo policyPlanRepo;
    private final PolicyRepo policyRepo;
    private final UserRepo userRepo;
    private final ModelMapper mapper;

    public String generatePolicyNumber(String tenantCode, Long policyId) {
        int year = Year.now().getValue();
        return String.format("POL-%s-%d-%05d", tenantCode, year, policyId);
    }

    @Override
    @Transactional
    public PolicyPlanResponseDto createPolicyPlan(PolicyPlanRequestDto requestDto) {
        User admin = currentUserService.getCurrentActiveUser();
        Tenant tenant = admin.getTenant();

        PolicyPlan plan = new PolicyPlan();
        plan.setTenant(tenant);
        plan.setPlanName(requestDto.getPlanName());
        plan.setPolicyType(requestDto.getPolicyType());
        plan.setMaxIdvCoverage(requestDto.getMaxIdvCoverage());
        plan.setAnnualPremium(requestDto.getAnnualPremium());
        plan.setDescription(requestDto.getDescription());
        plan.setActive(true);

        plan = policyPlanRepo.save(plan);
        log.info("Admin {} created new PolicyPlan ID: {}", admin.getEmail(), plan.getPlanId());

        return mapper.map(plan, PolicyPlanResponseDto.class);
    }

    @Override
    @Transactional(readOnly = true)
    public List<PolicyPlanResponseDto> getAllPolicyPlans() {
        User admin = currentUserService.getCurrentActiveUser();
        Tenant tenant = admin.getTenant();

        return policyPlanRepo.findByTenant(tenant).stream()
                .map(plan -> mapper.map(plan, PolicyPlanResponseDto.class))
                .toList();
    }

    @Override
    @Transactional
    public PolicyResponseDto issueDirectPolicy(AdminIssuePolicyDto requestDto) {
        User admin = currentUserService.getCurrentActiveUser();
        Tenant tenant = admin.getTenant();

        User targetUser = userRepo.findById(requestDto.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("User not found with ID: " + requestDto.getUserId()));

        PolicyPlan plan = null;
        if (requestDto.getPlanId() != null) {
            plan = policyPlanRepo.findById(requestDto.getPlanId()).orElse(null);
        }

        Policy policy = new Policy();
        policy.setTenant(tenant);
        policy.setUser(targetUser);
        policy.setPolicyPlan(plan);
        policy.setVehicleNumber(requestDto.getVehicleNumber());
        policy.setVehicleMakeModel(requestDto.getVehicleMakeModel());
        policy.setInsuredDeclaredValue(requestDto.getInsuredDeclaredValue());
        policy.setPolicyStatus(PolicyStatus.ACTIVE);
        policy.setPolicyStartDate(Instant.now());
        policy.setPolicyEndDate(Instant.now().plus(365, ChronoUnit.DAYS));

        // Temporary unique string before ID generation
        policy.setPolicyNumber("TEMP-" + System.currentTimeMillis());
        policy = policyRepo.save(policy);

        // Update real policy number
        policy.setPolicyNumber(generatePolicyNumber(tenant.getTenantCode(), policy.getPolicyId()));
        policy = policyRepo.save(policy);

        log.info("Admin {} issued direct policy {} to user {}", admin.getEmail(), policy.getPolicyNumber(), targetUser.getEmail());

        return mapToPolicyResponseDto(policy);
    }

    @Override
    @Transactional(readOnly = true)
    public List<PolicyResponseDto> getAllTenantPolicies() {
        User admin = currentUserService.getCurrentActiveUser();
        Tenant tenant = admin.getTenant();

        return policyRepo.findByTenant(tenant).stream()
                .map(this::mapToPolicyResponseDto)
                .toList();
    }

    private PolicyResponseDto mapToPolicyResponseDto(Policy policy) {
        PolicyResponseDto dto = new PolicyResponseDto();
        dto.setPolicyId(policy.getPolicyId());
        dto.setPolicyNumber(policy.getPolicyNumber());
        dto.setPlanName(policy.getPolicyPlan() != null ? policy.getPolicyPlan().getPlanName() : "Custom Direct Policy");
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
