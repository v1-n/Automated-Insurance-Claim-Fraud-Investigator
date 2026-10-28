package com.insurancefraud.service.impl;

import com.insurancefraud.entity.UserDevice;
import com.insurancefraud.repository.UserDeviceRepo;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import com.insurancefraud.entity.Tenant;
import com.insurancefraud.entity.User;
import com.insurancefraud.service.UserDeviceService;

import java.time.Instant;

@Slf4j
@RequiredArgsConstructor
@Service
public class UserDeviceServiceImpl implements UserDeviceService {

    private final UserDeviceRepo userDeviceRepo;

    @Override
    public void registerDevice(User user, Tenant tenant, String token, String platform) {

        if (!StringUtils.hasText(token)) {
            throw new IllegalArgumentException("Device token is required to register device");
        }

        UserDevice device = userDeviceRepo.findByTokenAndUser_UserIdAndTenant_TenantId(token, user.getUserId(), tenant.getTenantId())
                .orElseGet(UserDevice::new);

        device.setToken(token);
        device.setUser(user);
        device.setTenant(tenant);
        device.setPlatform(platform);
        device.setActive(true);
        device.setLastSeenAt(Instant.now());

        userDeviceRepo.save(device);
        log.info("Registered FCM device token for user {} ({})", user.getEmail(), platform);
    }

}
