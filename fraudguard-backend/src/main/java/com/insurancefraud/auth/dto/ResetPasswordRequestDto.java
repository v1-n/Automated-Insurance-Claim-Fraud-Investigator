package com.insurancefraud.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class ResetPasswordRequestDto {

    @NotBlank
    private String token;

    @NotBlank
    @Size(min = 8)
    private String newPassword;
}