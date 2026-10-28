package com.insurancefraud;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.insurancefraud.entity.User;
import com.insurancefraud.notification.service.NotificationChannel;
import com.insurancefraud.notification.service.impl.PushNotificationServiceImpl;
import org.junit.jupiter.api.Test;

import java.io.FileInputStream;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.*;

class FirebaseTest {

    @Test
    void shouldLoadFirebaseCredentials(User user, String token) throws Exception {


        try (FileInputStream serviceAccount =
                     new FileInputStream("src/main/resources/fraudguard-notification-firebase-adminsdk-fbsvc-9788b21f7a.json")) {

            GoogleCredentials credentials =
                    GoogleCredentials.fromStream(serviceAccount);

            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(credentials)
                    .build();

            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
            }

            System.out.println(
                    "Firebase credentials loaded and initialized successfully"
            );

            NotificationChannel fcmservice = new PushNotificationServiceImpl();
            fcmservice.sendNotification(
                    user.getFullName(),
                    "Test Body",
                        token);


        }
    }
}