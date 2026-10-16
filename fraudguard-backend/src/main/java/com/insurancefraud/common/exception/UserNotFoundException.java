package com.insurancefraud.common.exception;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class UserNotFoundException extends RuntimeException{
    public UserNotFoundException(String msg){
        super(msg);
        log.info("UserNotFoundException : {}",msg);

    }
}
