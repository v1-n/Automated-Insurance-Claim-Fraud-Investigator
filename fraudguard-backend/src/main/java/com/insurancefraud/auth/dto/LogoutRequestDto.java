package com.insurancefraud.auth.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class LogoutRequestDto {

    @NotBlank(message = "Refresh token is required")
    private String refreshToken;
}