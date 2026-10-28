package com.insurancefraud.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class LoginRequestDto {

    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    private String email;

    @NotBlank(message = "Password is required")
    private String password;

    @NotBlank(message = "FCM token is required")
    private String fcmToken;

    @NotBlank(message = "Platform is required")
    @Pattern(
            regexp = "ANDROID|IOS|WEB",
            message = "Platform must be ANDROID, IOS, or WEB"
    )
    private String platform;
}