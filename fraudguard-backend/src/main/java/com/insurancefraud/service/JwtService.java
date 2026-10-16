package com.insurancefraud.service;

import com.insurancefraud.entity.User;

public interface JwtService {

    String generateEmailVerificationToken(User user);

    String generateToken(User user);

    String generateRefreshToken(User user);

    Long extractUserId(String token);

    // Only accepts ACCESS tokens — rejects email/reset/refresh tokens used as Bearer
    Long extractUserIdFromAccessToken(String token);

    String generatePasswordResetToken(User user);
}