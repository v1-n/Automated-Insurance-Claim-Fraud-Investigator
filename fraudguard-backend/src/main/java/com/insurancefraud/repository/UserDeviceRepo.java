
package com.insurancefraud.repository;

import com.insurancefraud.entity.UserDevice;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserDeviceRepo
        extends JpaRepository<UserDevice, Long> {

    Optional<UserDevice> findFirstByTokenAndUser_UserIdAndTenant_TenantId(
            String token,
            Long userId,
            Long tenantId
    );

    Optional<UserDevice> findFirstByUser_UserIdAndTenant_TenantId(long userId, long tenantId);

    List<UserDevice> findAllByUser_UserIdAndTenant_TenantIdAndActiveTrue(Long recipientId, Long tenantId);
}
