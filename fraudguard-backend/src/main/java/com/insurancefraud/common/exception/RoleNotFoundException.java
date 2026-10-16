package com.insurancefraud.common.exception;

import lombok.extern.slf4j.Slf4j;


@Slf4j
public class RoleNotFoundException extends RuntimeException{
    public RoleNotFoundException(String msg) {
        super(msg);
        log.error("RoleNotFoundException : {}", msg);
    }
}
