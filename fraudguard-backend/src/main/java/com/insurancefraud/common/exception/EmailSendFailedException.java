package com.insurancefraud.common.exception;

import lombok.extern.slf4j.Slf4j;

@Slf4j
public class EmailSendFailedException extends RuntimeException {

    public EmailSendFailedException(String message) {
        super(message);
        log.info("EmailSendFailedException : {}",message);

    }
}