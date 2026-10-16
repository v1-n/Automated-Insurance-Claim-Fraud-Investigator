package com.insurancefraud.auth.dto;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class UserResponseDto {

    private Long userId;

    private String fullName;

    private String email;

    private String role;

    private String tenantCode;

    private String status;

    private String avatarUrl;
}