package com.insurancefraud.notification.service.impl;

import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import com.insurancefraud.notification.service.NotificationChannel;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class PushNotificationServiceImpl implements NotificationChannel {

    public static final String NOTIFICATION_CHANNEL_ID = "fraudguard_channel";

    @Override
    public void sendNotification(String title, String body, String deviceToken) {

        Message message = Message.builder()
                .setToken(deviceToken)
                .setNotification(Notification.builder()
                        .setTitle(title)
                        .setBody(body)
                        .build())
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder()
                                .setChannelId(NOTIFICATION_CHANNEL_ID)
                                .setPriority(AndroidNotification.Priority.HIGH)
                                .setDefaultSound(true)
                                .setDefaultVibrateTimings(true)
                                .build())
                        .build())
                .build();

        try {
            String response = FirebaseMessaging.getInstance().send(message);
            log.info("FCM notification sent successfully. Response: {}", response);
        }catch (Exception e) {
            log.error("Error occurred while sending FCM notification", e);
        }
    }
}
