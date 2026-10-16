package com.insurancefraud.service.impl;

import com.insurancefraud.entity.User;
import com.insurancefraud.service.JwtService;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.time.Duration;
import java.util.Date;

@Slf4j
@Service
public class JwtServiceImpl implements JwtService {

    @Value("${jwt.secret}")
    private String secret;

    @Value("${jwt.access.expiration}")
    private Duration accessExpiration;

    @Value("${jwt.refresh.expiration}")
    private Duration refreshExpiration;

    private SecretKey getSignKey() {
        return Keys.hmacShaKeyFor(secret.getBytes());
    }

    @Override
    public String generateEmailVerificationToken(User user) {
        return Jwts.builder()
                .subject(String.valueOf(user.getUserId()))
                .claim("type", "EMAIL_VERIFICATION")
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 1000 * 60 * 30))
                .signWith(getSignKey())
                .compact();
    }

    @Override
    public String generateToken(User user) {
        return Jwts.builder()
                .subject(String.valueOf(user.getUserId()))
                .claim("role", user.getRole().getRoleCode().name())
                .claim("tenantId", user.getTenant().getTenantId())
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + accessExpiration.toMillis()))
                .signWith(getSignKey())
                .compact();
    }

    @Override
    public String generateRefreshToken(User user) {
        return Jwts.builder()
                .subject(String.valueOf(user.getUserId()))
                .claim("type", "REFRESH")
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + refreshExpiration.toMillis()))
                .signWith(getSignKey())
                .compact();
    }

    @Override
    public Long extractUserId(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(getSignKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();

        return Long.parseLong(claims.getSubject());
    }

    @Override
    public Long extractUserIdFromAccessToken(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(getSignKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();

        // Access tokens have NO 'type' claim
        // Email/Refresh/Reset tokens all have a 'type' claim → reject them
        String type = claims.get("type", String.class);
        if (type != null) {
            throw new io.jsonwebtoken.JwtException(
                "Invalid token type for authentication. Expected access token, got: " + type
            );
        }

        return Long.parseLong(claims.getSubject());
    }


    @Override
    public String generatePasswordResetToken(User user) {
        return Jwts.builder()
                .subject(String.valueOf(user.getUserId()))
                .claim("type", "PASSWORD_RESET")
                .issuedAt(new Date())
                .expiration(
                        new Date(
                                System.currentTimeMillis()
                                        + (1000 * 60 * 15)  //30min
                        )
                )
                .signWith(getSignKey())
                .compact();
    }
}