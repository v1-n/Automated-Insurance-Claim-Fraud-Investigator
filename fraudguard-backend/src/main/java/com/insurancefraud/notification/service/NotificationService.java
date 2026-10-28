package com.insurancefraud.notification.service;

import com.insurancefraud.notification.dto.NotificationResponseDto;
import com.insurancefraud.notification.dto.UnreadCountResponseDto;
import org.springframework.data.domain.Page;

public interface NotificationService {

    Page<NotificationResponseDto> getMyNotifications(int page, int size);

    UnreadCountResponseDto getMyUnreadCount();

    NotificationResponseDto markAsRead(Long notificationId);
}
