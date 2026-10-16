package com.insurancefraud.auth.controller;

import com.insurancefraud.auth.dto.*;
import com.insurancefraud.auth.service.RefreshTokenService;
import com.insurancefraud.common.payload.ApiResponse;
import com.insurancefraud.auth.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import jakarta.validation.Valid;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;

@Slf4j
@RestController
@RequiredArgsConstructor
@Tag(name = "Authentication APIs")
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;
    private final RefreshTokenService refreshTokenService;


    @Operation(summary = "Register user")
    @PostMapping("/register")
    ResponseEntity<ApiResponse<Void>> register(@Valid @RequestBody RegisterRequestDto requestDto){
        authService.registerUser(requestDto);
        ApiResponse<Void> response = new ApiResponse<>(
                true,
                "Registration successful. Please verify your email.",
                HttpStatus.CREATED.value(),
                Instant.now(),
                null
        );
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @Operation(summary = "send email verification")
    @GetMapping(value = "/verify-email", produces = "text/html")
    public String verifyEmail(@RequestParam String token) {
        try {
            authService.verifyEmail(token);
            return """
                <!DOCTYPE html>
                <html lang="en">
                <head>
                    <meta charset="UTF-8">
                    <title>Email Verified - FraudGuard AI</title>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <style>
                        body {
                            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif;
                            background-color: #0f172a;
                            color: #f8fafc;
                            display: flex;
                            justify-content: center;
                            align-items: center;
                            height: 100vh;
                            margin: 0;
                        }
                        .card {
                            background: rgba(30, 41, 59, 0.7);
                            backdrop-filter: blur(12px);
                            border: 1px solid rgba(255, 255, 255, 0.08);
                            padding: 40px 30px;
                            border-radius: 20px;
                            text-align: center;
                            box-shadow: 0 15px 35px rgba(0, 0, 0, 0.4);
                            max-width: 420px;
                            width: 90%;
                        }
                        .circle {
                            width: 80px;
                            height: 80px;
                            background: rgba(16, 185, 129, 0.15);
                            border-radius: 50%;
                            display: flex;
                            justify-content: center;
                            align-items: center;
                            margin: 0 auto 24px;
                            color: #10b981;
                            font-size: 36px;
                            font-weight: bold;
                            animation: pop 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
                        }
                        h1 {
                            font-size: 26px;
                            font-weight: 700;
                            margin: 0 0 12px;
                            background: linear-gradient(135deg, #34d399, #059669);
                            -webkit-background-clip: text;
                            -webkit-text-fill-color: transparent;
                        }
                        p {
                            color: #94a3b8;
                            font-size: 15px;
                            line-height: 1.6;
                            margin: 0 0 32px;
                        }
                        .btn {
                            display: inline-block;
                            background: linear-gradient(135deg, #10b981, #059669);
                            color: white;
                            text-decoration: none;
                            padding: 12px 32px;
                            border-radius: 10px;
                            font-weight: 600;
                            box-shadow: 0 4px 14px rgba(16, 185, 129, 0.35);
                            transition: transform 0.2s, box-shadow 0.2s;
                        }
                        .btn:hover {
                            transform: translateY(-2px);
                            box-shadow: 0 6px 20px rgba(16, 185, 129, 0.5);
                        }
                        @keyframes pop {
                            0% { transform: scale(0); }
                            100% { transform: scale(1); }
                        }
                    </style>
                </head>
                <body>
                    <div class="card">
                        <div class="circle">✓</div>
                        <h1>Email Verified!</h1>
                        <p>Your account has been successfully verified. You can now close this window and log in to the FraudGuard AI app.</p>
                        <a href="#" class="btn" onclick="window.close(); return false;">Close Tab</a>
                    </div>
                </body>
                </html>
                """;
        } catch (Exception e) {
            return """
                <!DOCTYPE html>
                <html lang="en">
                <head>
                    <meta charset="UTF-8">
                    <title>Verification Failed - FraudGuard AI</title>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <style>
                        body {
                            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif;
                            background-color: #0f172a;
                            color: #f8fafc;
                            display: flex;
                            justify-content: center;
                            align-items: center;
                            height: 100vh;
                            margin: 0;
                        }
                        .card {
                            background: rgba(30, 41, 59, 0.7);
                            backdrop-filter: blur(12px);
                            border: 1px solid rgba(255, 255, 255, 0.08);
                            padding: 40px 30px;
                            border-radius: 20px;
                            text-align: center;
                            box-shadow: 0 15px 35px rgba(0, 0, 0, 0.4);
                            max-width: 420px;
                            width: 90%;
                        }
                        .circle {
                            width: 80px;
                            height: 80px;
                            background: rgba(239, 68, 68, 0.15);
                            border-radius: 50%;
                            display: flex;
                            justify-content: center;
                            align-items: center;
                            margin: 0 auto 24px;
                            color: #ef4444;
                            font-size: 36px;
                            font-weight: bold;
                        }
                        h1 {
                            font-size: 26px;
                            font-weight: 700;
                            margin: 0 0 12px;
                            background: linear-gradient(135deg, #f87171, #dc2626);
                            -webkit-background-clip: text;
                            -webkit-text-fill-color: transparent;
                        }
                        p {
                            color: #94a3b8;
                            font-size: 15px;
                            line-height: 1.6;
                            margin: 0 0 32px;
                        }
                        .btn {
                            display: inline-block;
                            background: #334155;
                            color: white;
                            text-decoration: none;
                            padding: 12px 32px;
                            border-radius: 10px;
                            font-weight: 600;
                            transition: background-color 0.2s;
                        }
                        .btn:hover {
                            background-color: #475569;
                        }
                    </style>
                </head>
                <body>
                    <div class="card">
                        <div class="circle">✗</div>
                        <h1>Verification Failed</h1>
                        <p>The verification link has expired, is invalid, or the email has already been verified.</p>
                        <a href="#" class="btn" onclick="window.close(); return false;">Close Tab</a>
                    </div>
                </body>
                </html>
                """;
        }
    }

    @Operation(summary = "Login user")
    @PostMapping("/login")
    public ResponseEntity<ApiResponse<LoginResponseDto>> login(@Valid @RequestBody LoginRequestDto loginDto) {

        LoginResponseDto data = authService.authenticateUser(loginDto);

        ApiResponse<LoginResponseDto> response = new ApiResponse<>(
                true,
                "Login successful",
                200,
                Instant.now(),
                data
        );

        return ResponseEntity.ok(response);
    }

    @Operation(summary = "Logout user")
    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>>  logout(@Valid @RequestBody LogoutRequestDto logoutDto){

        authService.logout(logoutDto);
        ApiResponse<Void>  response = new ApiResponse<>(
                true,
                "Logged out successfully",
                200,
                Instant.now(),
                null
        );

        return  ResponseEntity.ok(response);
    }

    @Operation(summary = "Delete user account ")
    @PostMapping("/delete-account")
    public ResponseEntity<ApiResponse<Void>> deleteAccount(@Valid @RequestBody DeleteRequestDto deleteDto){

        log.info("DELETE ACCOUNT API HIT");
        authService.delete(deleteDto);
        log.info("ACCOUNT DELETED");

        ApiResponse<Void> response = new ApiResponse<>(
                true,
                "Account deleted successfully",
                200,
                Instant.now(),
                null
        );
        return  ResponseEntity.ok(response);
    }

    @Operation(summary = "send email reverification")
    @PostMapping("/resend-verification")
    public ResponseEntity<ApiResponse<String>> resend(@Valid @RequestBody ResendVerificationRequest request) {

        authService.resendVerification(request.getEmail());

        return ResponseEntity.ok(
                new ApiResponse<>(true, "Verification email sent", 200, Instant.now(), null)
        );
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<ApiResponse<Void>> forgotPassword(
            @Valid
            @RequestBody
            ForgotPasswordRequestDto requestDto
    ) {
        authService.forgotPassword(requestDto);
        ApiResponse<Void> response =
                new ApiResponse<>(
                        true,
                        "If email exists, reset link sent",
                        200,
                        Instant.now(),
                        null
                );
        return ResponseEntity.ok(response);
    }

    @PostMapping("/reset-password")
    public ResponseEntity<ApiResponse<Void>>
    resetPassword(
            @Valid
            @RequestBody
            ResetPasswordRequestDto requestDto
    ) {
        authService.resetPassword(requestDto);
        return ResponseEntity.ok(
                new ApiResponse<>(
                        true,
                        "Password reset successful",
                        200,
                        Instant.now(),
                        null
                )
        );
    }

    @PostMapping("/refresh")
    public ResponseEntity<
            ApiResponse<RefreshTokenResponseDto>
            > refreshToken(

            @RequestBody
            RefreshTokenRequestDto request
    ) {

        RefreshTokenResponseDto data =
                refreshTokenService.refreshToken(
                        request
                );

        return ResponseEntity.ok(
                new ApiResponse<>(
                        true,
                        "Token refreshed successfully",
                        200,
                        Instant.now(),
                        data
                )
        );
    }

    @PostMapping("/change-password")
    public ResponseEntity<ApiResponse<Void>> changePassword(
            @Valid @RequestBody ChangePasswordRequestDto requestDto
    ) {
        authService.changePassword(requestDto);
        return ResponseEntity.ok(
                new ApiResponse<>(
                        true,
                        "Password changed successfully",
                        200,
                        Instant.now(),
                        null
                )
        );
    }
}
