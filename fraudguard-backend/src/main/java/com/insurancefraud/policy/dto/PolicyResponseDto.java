package com.insurancefraud.policy.dto;

import com.insurancefraud.enums.PolicyStatus;
import com.insurancefraud.enums.PolicyType;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;

@Getter
@Setter
public class PolicyResponseDto {

    private Long policyId;
    private String policyNumber;
    private String planName;
    private PolicyType policyType;
    private String vehicleNumber;
    private String vehicleMakeModel;
    private BigDecimal insuredDeclaredValue;
    private PolicyStatus policyStatus;
    private Instant policyStartDate;
    private Instant policyEndDate;
    private String userName;
    private String userEmail;
    private String tenantCode;
}
