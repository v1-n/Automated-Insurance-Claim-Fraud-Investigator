package com.insurancefraud.notification.dto;

import com.insurancefraud.enums.EventType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NotificationResponseDto {
    private Long notificationId;
    private String title;
    private String body;
    private EventType eventType;
    private Long referenceId;
    private boolean read;
    private Instant createdAt;
}
