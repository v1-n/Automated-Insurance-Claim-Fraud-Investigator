package com.insurancefraud.fraud.consumer;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.insurancefraud.enums.AnalysisRunStatus;
import com.insurancefraud.fraud.repository.ClaimAnalysisRunRepo;
import com.insurancefraud.fraud.service.FraudAnalysisService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;

@Slf4j
@Component
@RequiredArgsConstructor
public class ClaimAnalysisConsumer {

    private final FraudAnalysisService fraudAnalysisService;
    private final ObjectMapper objectMapper;
    private final ClaimAnalysisRunRepo claimAnalysisRunRepo;

    @RabbitListener(queues = "${rabbitmq.queue.claim.analysis}", concurrency = "2")
    public void consumeClaimAnalysisJob(Message message) {
        String payloadStr = "";
        try {
            payloadStr = new String(message.getBody(), StandardCharsets.UTF_8);
            JsonNode payload = objectMapper.readTree(payloadStr);
            JsonNode claimIdNode = payload.get("claimId");

            if (claimIdNode == null
                    || claimIdNode.isNull()
                    || !claimIdNode.canConvertToLong()) {
                throw new IllegalArgumentException(
                        "Missing or invalid claimId in message"
                );
            }

            Long claimId = claimIdNode.longValue();
            log.info("Received claim analysis job from RabbitMQ for Claim ID: {}", claimId);

            // Extract eventId from header or JSON envelope
            Long eventId = null;
            Object headerEventId = message.getMessageProperties().getHeader("eventId");
            if (headerEventId instanceof Number n) {
                eventId = n.longValue();
            } else if (payload.has("eventId") && !payload.get("eventId").isNull()) {
                eventId = payload.get("eventId").asLong();
            }

            // Deduplication Guard: Skip ONLY if a run for this outbox event was already COMPLETED!
            // If the previous attempt FAILED, allow Spring AMQP retry to execute again.
            if (eventId != null && claimAnalysisRunRepo.existsByOutboxEventIdAndStatus(eventId, AnalysisRunStatus.COMPLETED)) {
                log.info("OutboxEvent #{} for Claim ID {} was already completed. Skipping duplicate job.",
                        eventId, claimId);
                return;
            }

            String triggerType = message.getMessageProperties().getReceivedRoutingKey();
            if (triggerType == null || triggerType.isBlank()) {
                triggerType = payload.has("eventType") ? payload.get("eventType").asText() : "UNKNOWN";
            }

            // Invoke Python AI Microservice, save risk score & evidence flags to DB
            fraudAnalysisService.analyzeClaimAsync(claimId, eventId, triggerType);
            log.info("AI Analysis completed successfully for Claim ID: {}", claimId);

        } catch (Exception ex) {
            log.error("Failed to process claim analysis job for message. Error: {}", ex.getMessage(), ex);
            throw new RuntimeException(ex);
        }
    }
}
