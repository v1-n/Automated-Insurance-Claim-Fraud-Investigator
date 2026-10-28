package com.insurancefraud.notification.service;


public interface NotificationChannel {
    public void sendNotification(String title, String body, String deviceToken);
}
