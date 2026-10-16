package com.insurancefraud.common.exception;

public class TokenAlreadyRevokedException extends RuntimeException {
    public TokenAlreadyRevokedException(String message) {
        super(message);
    }
}