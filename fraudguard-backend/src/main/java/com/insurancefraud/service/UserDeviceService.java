package com.insurancefraud.service;

import com.insurancefraud.entity.Tenant;
import com.insurancefraud.entity.User;

public interface UserDeviceService {

    public void registerDevice(
            User user,
            Tenant tenant,
            String token,
            String platform);
}
