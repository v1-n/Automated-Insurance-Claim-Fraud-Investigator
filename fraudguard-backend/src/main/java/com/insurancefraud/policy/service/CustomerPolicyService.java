package com.insurancefraud.policy.service;

import com.insurancefraud.policy.dto.CustomerSelectPolicyDto;
import com.insurancefraud.policy.dto.PolicyPlanResponseDto;
import com.insurancefraud.policy.dto.PolicyResponseDto;

import java.util.List;

public interface CustomerPolicyService {

    List<PolicyPlanResponseDto> getAvailablePlans();

    PolicyResponseDto selectAndActivatePolicy(CustomerSelectPolicyDto requestDto);

    List<PolicyResponseDto> getMyPolicies();
}
