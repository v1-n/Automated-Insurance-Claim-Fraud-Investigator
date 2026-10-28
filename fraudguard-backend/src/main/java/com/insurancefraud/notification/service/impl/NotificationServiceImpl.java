package com.insurancefraud.notification.service.impl;

import com.insurancefraud.common.exception.ResourceNotFoundException;
import com.insurancefraud.common.security.CurrentUserService;
import com.insurancefraud.entity.Notifications;
import com.insurancefraud.entity.User;
import com.insurancefraud.notification.dto.NotificationResponseDto;
import com.insurancefraud.notification.dto.UnreadCountResponseDto;
import com.insurancefraud.notification.service.NotificationService;
import com.insurancefraud.repository.NotificationRepo;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationServiceImpl implements NotificationService {

    private final NotificationRepo notificationRepo;
    private final CurrentUserService currentUserService;

    @Override
    @Transactional(readOnly = true)
    public Page<NotificationResponseDto> getMyNotifications(int page, int size) {
        User user = currentUserService.getCurrentActiveUser();
        PageRequest pageRequest = PageRequest.of(page, size);

        return notificationRepo
                .findByUser_UserIdAndTenant_TenantIdOrderByCreatedAtDesc(
                        user.getUserId(),
                        user.getTenant().getTenantId(),
                        pageRequest
                )
                .map(this::mapToDto);
    }

    @Override
    @Transactional(readOnly = true)
    public UnreadCountResponseDto getMyUnreadCount() {
        User user = currentUserService.getCurrentActiveUser();
        long unread = notificationRepo.countByUser_UserIdAndTenant_TenantIdAndReadFalse(
                user.getUserId(),
                user.getTenant().getTenantId()
        );
        return new UnreadCountResponseDto(unread);
    }

    @Override
    @Transactional
    public NotificationResponseDto markAsRead(Long notificationId) {
        User user = currentUserService.getCurrentActiveUser();

        Notifications notification = notificationRepo
                .findByNotificationIdAndUser_UserIdAndTenant_TenantId(
                        notificationId,
                        user.getUserId(),
                        user.getTenant().getTenantId()
                )
                .orElseThrow(() -> new ResourceNotFoundException("Notification not found with ID: " + notificationId));

        if (!notification.isRead()) {
            notification.setRead(true);
            notification = notificationRepo.save(notification);
        }

        return mapToDto(notification);
    }

    private NotificationResponseDto mapToDto(Notifications entity) {
        return NotificationResponseDto.builder()
                .notificationId(entity.getNotificationId())
                .title(entity.getTitle())
                .body(entity.getBody())
                .eventType(entity.getEventType())
                .referenceId(entity.getReferenceId())
                .read(entity.isRead())
                .createdAt(entity.getCreatedAt())
                .build();
    }
}
