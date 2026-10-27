package com.insurancefraud.fraud.consumer;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.insurancefraud.claim.repository.ClaimRepo;
import com.insurancefraud.enums.AiStatus;
import com.insurancefraud.enums.EventType;
import com.insurancefraud.outbox.service.OutboxService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;

@Slf4j
@Component
@RequiredArgsConstructor
public class ClaimAnalysisDlqConsumer {

    private final ClaimRepo claimRepo;
    private final ObjectMapper objectMapper;
    private final OutboxService outboxService;

    @RabbitListener(queues = "${rabbitmq.queue.claim.analysis}.dlq")
    @Transactional
    public void processDeadLetterMessage(Message message) {
        try {
            String body = new String(message.getBody(), StandardCharsets.UTF_8);
            JsonNode payload = objectMapper.readTree(body);

            if (payload.has("claimId") && !payload.get("claimId").isNull()) {
                Long claimId = payload.get("claimId").asLong();
                claimRepo.findByClaimIdAndIsDeletedFalse(claimId).ifPresent(claim -> {
                    if (claim.getAiStatus() != AiStatus.DONE) {
                        claim.setAiStatus(AiStatus.FAILED);
                        claimRepo.save(claim);
                        outboxService.record(EventType.AI_ANALYSIS_FAILED, claim);
                        log.warn("Retries exhausted for Claim #{}. Marked aiStatus=FAILED from Dead Letter Queue.",
                                claim.getClaimNumber());
                    } else {
                        log.warn("Claim #{} retries exhausted in DLQ, but current status is already DONE. Leaving DONE intact.",
                                claim.getClaimNumber());
                    }
                });
            }
        } catch (Exception ex) {
            log.error("Failed to process dead-lettered claim analysis message: {}", ex.getMessage(), ex);
        }
    }
}
