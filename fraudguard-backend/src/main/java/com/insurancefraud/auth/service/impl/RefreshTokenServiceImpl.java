package com.insurancefraud.auth.service.impl;

import com.insurancefraud.auth.dto.RefreshTokenRequestDto;
import com.insurancefraud.auth.dto.RefreshTokenResponseDto;
import com.insurancefraud.auth.repository.RefreshTokenRepo;
import com.insurancefraud.auth.service.RefreshTokenService;
import com.insurancefraud.common.exception.UnauthorizedException;
import com.insurancefraud.entity.RefreshToken;
import com.insurancefraud.entity.User;
import com.insurancefraud.service.JwtService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional
public class RefreshTokenServiceImpl implements RefreshTokenService {

    private final RefreshTokenRepo refreshTokenRepo;
    private final JwtService jwtService;

    @Override
    public RefreshTokenResponseDto refreshToken(RefreshTokenRequestDto request) {

        RefreshToken oldToken = refreshTokenRepo
                .findByToken(request.getRefreshToken())
                .orElseThrow(() -> new UnauthorizedException("Invalid refresh token"));

        // FIX #4 — Check revocation BEFORE checking expiry
        // A logged-out user's token is revoked; must not generate new access token
        if (oldToken.isRevoked()) {
            throw new UnauthorizedException("Refresh token has been revoked. Please log in again.");
        }

        // Check expiry
        if (oldToken.getExpiresAt().isBefore(Instant.now())) {
            refreshTokenRepo.delete(oldToken);
            throw new UnauthorizedException("Refresh token expired. Please log in again.");
        }

        User user = oldToken.getUser();

        // FIX #3 — Refresh Token Rotation
        // Revoke the OLD token so it can never be reused
        oldToken.setRevoked(true);
        refreshTokenRepo.save(oldToken);

        // Issue brand-new refresh token
        String newRefreshTokenString = jwtService.generateRefreshToken(user);
        RefreshToken newRefreshToken = new RefreshToken();
        newRefreshToken.setUser(user);
        newRefreshToken.setToken(newRefreshTokenString);
        newRefreshToken.setExpiresAt(Instant.now().plus(Duration.ofDays(7)));
        refreshTokenRepo.save(newRefreshToken);

        // Issue new access token
        String newAccessToken = jwtService.generateToken(user);

        log.info("Refresh token rotated for user {}", user.getEmail());

        return new RefreshTokenResponseDto(newAccessToken, newRefreshTokenString);
    }
}