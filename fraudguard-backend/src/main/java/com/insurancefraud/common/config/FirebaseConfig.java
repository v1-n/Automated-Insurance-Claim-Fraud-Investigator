package com.insurancefraud.common.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

@Slf4j
@Configuration
public class FirebaseConfig {

    @Value("${firebase.config.path:}")
    private String configPath;

    @Value("${firebase.credentials.json:}")
    private String credentialsJson;

    @Bean
    public FirebaseApp firebaseApp() {
        if (!FirebaseApp.getApps().isEmpty()) {
            return FirebaseApp.getInstance();
        }

        InputStream serviceAccount = null;
        try {
            // 1. Environment Variable / Property: Raw JSON or Base64
            String envJson = System.getenv("FIREBASE_CREDENTIALS_JSON");
            if (envJson == null || envJson.isBlank()) {
                envJson = credentialsJson;
            }

            if (envJson != null && !envJson.isBlank()) {
                byte[] bytes;
                if (envJson.trim().startsWith("{")) {
                    bytes = envJson.getBytes(StandardCharsets.UTF_8);
                } else {
                    bytes = Base64.getDecoder().decode(envJson.trim());
                }
                serviceAccount = new ByteArrayInputStream(bytes);
                log.info("Loading Firebase credentials from FIREBASE_CREDENTIALS_JSON environment variable");
            }

            // 2. Secret file path (e.g. Render Secret Files /etc/secrets/firebase-adminsdk.json)
            if (serviceAccount == null) {
                String filePath = System.getenv("FIREBASE_CONFIG_PATH");
                if (filePath == null || filePath.isBlank()) {
                    filePath = configPath;
                }
                if (filePath != null && !filePath.isBlank()) {
                    File file = new File(filePath);
                    if (file.exists()) {
                        serviceAccount = new FileInputStream(file);
                        log.info("Loading Firebase credentials from file path: {}", filePath);
                    }
                }
            }

            // 3. Fallback: Classpath resource for local development
            if (serviceAccount == null) {
                ClassPathResource classPathResource =
                        new ClassPathResource("fraudguard-notification-firebase-adminsdk-fbsvc-9788b21f7a.json");
                if (classPathResource.exists()) {
                    serviceAccount = classPathResource.getInputStream();
                    log.info("Loading Firebase credentials from classpath resource");
                }
            }

            if (serviceAccount == null) {
                log.warn("No Firebase credentials found (checked FIREBASE_CREDENTIALS_JSON, FIREBASE_CONFIG_PATH, and classpath). Push notifications will be disabled.");
                return null;
            }

            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();

            FirebaseApp app = FirebaseApp.initializeApp(options);
            log.info("FirebaseApp initialized successfully: {}", app.getName());
            return app;
        } catch (Exception e) {
            log.error("Failed to initialize FirebaseApp: {}", e.getMessage(), e);
            return null;
        } finally {
            if (serviceAccount != null) {
                try {
                    serviceAccount.close();
                } catch (IOException ignored) {}
            }
        }
    }
}


