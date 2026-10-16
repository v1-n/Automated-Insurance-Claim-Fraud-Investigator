package com.insurancefraud.auth.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class RefreshTokenResponseDto {

    private String accessToken;
    private String refreshToken;

}