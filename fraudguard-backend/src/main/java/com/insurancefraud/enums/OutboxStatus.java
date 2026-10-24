package com.insurancefraud.enums;

public enum OutboxStatus {
    NEW,          // Event created, waiting to be picked up
    PROCESSING,   // Locked by a poller instance via FOR UPDATE SKIP LOCKED
    PUBLISHED,    // Successfully sent to RabbitMQ
    FAILED,       // RabbitMQ down or network glitch occurred; will retry
    DEAD          // Exceeded maximum retry attempts; requires manual admin intervention
}
