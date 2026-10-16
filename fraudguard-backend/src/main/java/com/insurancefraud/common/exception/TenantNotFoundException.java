package com.insurancefraud.common.exception;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class TenantNotFoundException extends RuntimeException {
    public TenantNotFoundException(String msg) {
        super(msg);
        log.error("TenantNotFoundException : {}", msg);
    }
}