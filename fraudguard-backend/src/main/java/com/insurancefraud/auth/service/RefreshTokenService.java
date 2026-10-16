package com.insurancefraud.auth.service;

import com.insurancefraud.auth.dto.RefreshTokenRequestDto;
import com.insurancefraud.auth.dto.RefreshTokenResponseDto;

public interface RefreshTokenService {

    RefreshTokenResponseDto refreshToken(
            RefreshTokenRequestDto request
    );

}