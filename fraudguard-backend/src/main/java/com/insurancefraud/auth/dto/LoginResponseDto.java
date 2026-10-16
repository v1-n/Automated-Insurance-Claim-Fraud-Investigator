    package com.insurancefraud.auth.dto;

    import lombok.Getter;
    import lombok.Setter;


    @Getter
    @Setter
    public class LoginResponseDto {

        private String accessToken;
        private String refreshToken;
        private UserResponseDto user;
    }