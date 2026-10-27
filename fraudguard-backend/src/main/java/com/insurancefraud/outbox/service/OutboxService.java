package com.insurancefraud.outbox.service;

import com.insurancefraud.entity.Claim;
import com.insurancefraud.enums.EventType;

import java.util.Map;

public interface OutboxService {

    void record(EventType eventType, Claim claim);

    void record(EventType eventType, Claim claim, Map<String, Object> extra);

    void record(EventType eventType, Claim claim, Map<String, Object> extra, Long actorId);
}
