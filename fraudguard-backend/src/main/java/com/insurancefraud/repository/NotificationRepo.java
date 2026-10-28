package com.insurancefraud.repository;

import com.insurancefraud.entity.Notifications;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface NotificationRepo extends JpaRepository<Notifications, Long> {

    Page<Notifications> findByUser_UserIdAndTenant_TenantIdOrderByCreatedAtDesc(
            Long userId,
            Long tenantId,
            Pageable pageable
    );

    long countByUser_UserIdAndTenant_TenantIdAndReadFalse(Long userId, Long tenantId);

    Optional<Notifications> findByNotificationIdAndUser_UserIdAndTenant_TenantId(
            Long notificationId,
            Long userId,
            Long tenantId
    );

    boolean existsByEventIdAndUser_UserId(Long eventId, Long userId);
}
