package com.insurancefraud.policy.service;

import com.insurancefraud.policy.dto.AdminIssuePolicyDto;
import com.insurancefraud.policy.dto.PolicyPlanRequestDto;
import com.insurancefraud.policy.dto.PolicyPlanResponseDto;
import com.insurancefraud.policy.dto.PolicyResponseDto;

import java.util.List;

public interface AdminPolicyService {

    PolicyPlanResponseDto createPolicyPlan(PolicyPlanRequestDto requestDto);

    List<PolicyPlanResponseDto> getAllPolicyPlans();

    PolicyResponseDto issueDirectPolicy(AdminIssuePolicyDto requestDto);

    List<PolicyResponseDto> getAllTenantPolicies();
}
