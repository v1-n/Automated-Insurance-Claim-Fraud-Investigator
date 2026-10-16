package com.insurancefraud.service.impl;

import com.insurancefraud.common.exception.EmailSendFailedException;
import com.insurancefraud.service.EmailService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;

@Service
@Slf4j
public class EmailServiceImpl implements EmailService {

    private final HttpClient httpClient = HttpClient.newHttpClient();

    @Value("${spring.mail.username}")
    private String senderEmail;

    @Value("${spring.mail.password}")
    private String apiKey;

    @Value("${app.frontend.url:http://localhost:5173}")
    private String frontendUrl;

    @Value("${app.backend.url:https://automated-insurance-claim-fraud-investigator-production.up.railway.app}")
    private String backendUrl;

    @Async("emailTaskExecutor")
    @Override
    public void sendVerificationEmail(String email, String token) {
        String link = backendUrl + "/api/v1/auth/verify-email?token=" + token;
        log.info("==========================================================================");
        log.info("VERIFICATION LINK FOR [{}]:", email);
        log.info("{}", link);
        log.info("==========================================================================");

        String htmlContent = """
                <div style="font-family: Arial, sans-serif; padding: 20px;">
                    <h2>Welcome to FraudGuard AI 🚀</h2>
                    <p>
                        Please verify your email by clicking the button below:
                    </p>
                    <a href="%s"
                       target="_blank"
                       style="
                           display:inline-block;
                           padding:10px 20px;
                           background-color:#4CAF50;
                           color:white;
                           text-decoration:none;
                           border-radius:5px;
                       ">
                       Verify Email
                    </a>
                    <p style="margin-top:20px;">
                        If you didn't request this, ignore this email.
                    </p>
                </div>
                """.formatted(link);

        sendEmailViaBrevo(email, "Verify Your Account", htmlContent);
    }

    @Async("emailTaskExecutor")
    @Override
    public void sendPasswordResetEmail(String email, String token) {
        String link = frontendUrl + "/reset-password?token=" + token;
        String htmlContent = """
                <div style="font-family: Arial, sans-serif; padding: 20px;">
                    <h2>Password Reset</h2>
                    <p>Click below to reset password:</p>
                    <a href="%s"
                       target="_blank"
                       style="
                           display:inline-block;
                           padding:10px 20px;
                           background-color:#2196F3;
                           color:white;
                           text-decoration:none;
                           border-radius:5px;
                       ">
                        Reset Password
                    </a>
                    <p style="margin-top:20px;">
                        If you didn't request this, ignore this email.
                    </p>
                </div>
                """.formatted(link);

        sendEmailViaBrevo(email, "Reset Your Password", htmlContent);
    }

    private void sendEmailViaBrevo(String toEmail, String subject, String htmlContent) {
        try {
            // Escape double quotes and newlines for the JSON payload
            String escapedHtml = htmlContent
                    .replace("\\", "\\\\")
                    .replace("\"", "\\\"")
                    .replace("\n", "\\n")
                    .replace("\r", "");

            String requestBody = """
                    {
                      "sender": {
                        "name": "FraudGuard AI",
                        "email": "%s"
                      },
                      "to": [
                        {
                          "email": "%s"
                        }
                      ],
                      "subject": "%s",
                      "htmlContent": "%s"
                    }
                    """.formatted(senderEmail, toEmail, subject, escapedHtml);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create("https://api.brevo.com/v3/smtp/email"))
                    .header("accept", "application/json")
                    .header("api-key", apiKey)
                    .header("content-type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody, StandardCharsets.UTF_8))
                        .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                log.info("Email successfully sent to {} via Brevo HTTP API", toEmail);
            } else {
                log.error("Failed to send email to {} via Brevo HTTP API. Status: {}, Body: {}", 
                        toEmail, response.statusCode(), response.body());
                throw new EmailSendFailedException("Brevo API error: " + response.statusCode());
            }
        } catch (Exception e) {
            log.error("Failed to send email to {} via Brevo HTTP API: {}", toEmail, e.getMessage(), e);
            throw new EmailSendFailedException("Unable to send email");
        }
    }
}