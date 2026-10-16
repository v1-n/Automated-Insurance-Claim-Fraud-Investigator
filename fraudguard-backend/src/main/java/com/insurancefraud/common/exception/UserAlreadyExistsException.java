package com.insurancefraud.common.exception;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class UserAlreadyExistsException extends RuntimeException{
    public UserAlreadyExistsException(String msg){
        super(msg);
        log.info("UserAlreadyExistsException : {}",msg);
    }
}
