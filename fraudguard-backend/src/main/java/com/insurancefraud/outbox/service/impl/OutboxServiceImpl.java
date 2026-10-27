package com.insurancefraud.outbox.service.impl;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.insurancefraud.common.security.CurrentUserService;
import com.insurancefraud.entity.Claim;
import com.insurancefraud.entity.OutboxEvent;
import com.insurancefraud.entity.User;
import com.insurancefraud.enums.AggregateType;
import com.insurancefraud.enums.EventType;
import com.insurancefraud.enums.OutboxStatus;
import com.insurancefraud.outbox.repository.OutboxEventRepo;
import com.insurancefraud.outbox.service.OutboxService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class OutboxServiceImpl implements OutboxService {

    private final OutboxEventRepo outboxEventRepo;
    private final ObjectMapper objectMapper;
    private final CurrentUserService currentUserService;

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void record(EventType eventType, Claim claim) {
        record(eventType, claim, Map.of(), null);
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void record(EventType eventType, Claim claim, Map<String, Object> extra) {
        record(eventType, claim, extra, null);
    }

    @Override
    @Transactional(propagation = Propagation.MANDATORY)
    public void record(EventType eventType, Claim claim, Map<String, Object> extra, Long actorId) {
        if (claim == null) {
            throw new IllegalArgumentException("Claim cannot be null when recording an outbox event");
        }

        Long resolvedActorId = actorId;
        if (resolvedActorId == null) {
            try {
                User activeUser = currentUserService.getCurrentActiveUser();
                if (activeUser != null) {
                    resolvedActorId = activeUser.getUserId();
                }
            } catch (Exception e) {
                // Background worker or unauthenticated context
                log.debug("No active user in security context for outbox event: {}", e.getMessage());
            }
        }

        Map<String, Object> envelope = new HashMap<>();
        envelope.put("claimId", claim.getClaimId());
        envelope.put("claimNumber", claim.getClaimNumber());
        envelope.put("tenantId", claim.getTenant() != null ? claim.getTenant().getTenantId() : null);
        envelope.put("customerId", claim.getUser() != null ? claim.getUser().getUserId() : null);
        envelope.put("investigatorId", claim.getAssignedInvestigator() != null ? claim.getAssignedInvestigator().getUserId() : null);
        envelope.put("actorId", resolvedActorId);
        envelope.put("eventType", eventType.name());
        envelope.put("timestamp", Instant.now().toString());

        if (extra != null && !extra.isEmpty()) {
            envelope.putAll(extra);
        }

        try {
            String payloadJson = objectMapper.writeValueAsString(envelope);

            OutboxEvent outboxEvent = new OutboxEvent();
            outboxEvent.setTenant(claim.getTenant());
            outboxEvent.setEventType(eventType);
            outboxEvent.setAggregateType(AggregateType.CLAIM);
            outboxEvent.setAggregateId(claim.getClaimId());
            outboxEvent.setPayload(payloadJson);
            outboxEvent.setStatus(OutboxStatus.NEW);
            outboxEvent.setAttempts(0);
            outboxEvent.setNextAttemptAt(Instant.now());

            outboxEventRepo.save(outboxEvent);

            log.info("Recorded OutboxEvent #{} [{}] for Claim #{}",
                    outboxEvent.getEventId(), eventType, claim.getClaimNumber());
        } catch (Exception e) {
            log.error("Failed to serialize or save OutboxEvent [{}]: {}", eventType, e.getMessage(), e);
            throw new RuntimeException("Failed to record outbox event for " + eventType, e);
        }
    }
}
