package com.insurancefraud.fraud.consumer;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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
            log.info("Received claim analysis job from RabbitMQ: {}", payloadStr);

            JsonNode payload = objectMapper.readTree(payloadStr);
            JsonNode claimIdNode = payload.get("claimId");

            if (claimIdNode == null
                    || claimIdNode.isNull()
                    || !claimIdNode.canConvertToLong()) {
                throw new IllegalArgumentException(
                        "Missing or invalid claimId in message: " + payloadStr
                );
            }

            Long claimId = claimIdNode.longValue();

            // Extract eventId from header or JSON envelope
            Long eventId = null;
            Object headerEventId = message.getMessageProperties().getHeader("eventId");
            if (headerEventId instanceof Number n) {
                eventId = n.longValue();
            } else if (payload.has("eventId") && !payload.get("eventId").isNull()) {
                eventId = payload.get("eventId").asLong();
            }

            // Deduplication Guard: If this exact outbox event was already processed, skip duplicate
            if (eventId != null && claimAnalysisRunRepo.existsByOutboxEventId(eventId)) {
                log.info("OutboxEvent #{} for Claim ID {} was already analyzed. Skipping duplicate job.",
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
            log.error("Failed to process claim analysis job: {}. Error: {}", payloadStr, ex.getMessage(), ex);
            throw new RuntimeException(ex);
        }
    }
}
