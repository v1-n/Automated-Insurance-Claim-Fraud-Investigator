package com.insurancefraud.policy.dto;

import com.insurancefraud.enums.PolicyType;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;

@Getter
@Setter
public class PolicyPlanResponseDto {

    private Long planId;
    private String planName;
    private PolicyType policyType;
    private BigDecimal maxIdvCoverage;
    private BigDecimal annualPremium;
    private String description;
    private boolean isActive;
    private Instant createdAt;
}
