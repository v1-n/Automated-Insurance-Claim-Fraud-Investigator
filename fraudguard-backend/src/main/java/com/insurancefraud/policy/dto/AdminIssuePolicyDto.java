package com.insurancefraud.policy.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class AdminIssuePolicyDto {

    @NotNull(message = "User ID is required")
    private Long userId;

    private Long planId;

    @NotBlank(message = "Vehicle number is required")
    private String vehicleNumber;

    @NotBlank(message = "Vehicle make & model is required")
    private String vehicleMakeModel;

    @NotNull(message = "Insured declared value is required")
    @DecimalMin(value = "1.0", message = "IDV must be greater than 0")
    private BigDecimal insuredDeclaredValue;
}
