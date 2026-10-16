package com.insurancefraud.service;

import jakarta.mail.MessagingException;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public interface EmailService {
    public void sendVerificationEmail(String email,String token);
    public void sendPasswordResetEmail(@NotBlank @Email String email, String token);
}
