package com.insurancefraud.common.security;

import com.insurancefraud.entity.User;

public interface CurrentUserService {

    User getCurrentUser();

    User getCurrentActiveUser();
}