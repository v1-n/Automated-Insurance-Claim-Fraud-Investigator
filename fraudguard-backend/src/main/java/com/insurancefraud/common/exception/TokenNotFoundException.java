package com.insurancefraud.common.exception;


public class TokenNotFoundException extends RuntimeException{
    public TokenNotFoundException(String msg){
        super(msg);
    }
}