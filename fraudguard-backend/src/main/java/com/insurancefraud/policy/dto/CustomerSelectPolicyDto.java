package com.insurancefraud.policy.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class CustomerSelectPolicyDto {

    @NotNull(message = "Plan ID is required")
    private Long planId;

    @NotBlank(message = "Vehicle number is required")
    private String vehicleNumber;

    @NotBlank(message = "Vehicle make & model is required")
    private String vehicleMakeModel;
}
