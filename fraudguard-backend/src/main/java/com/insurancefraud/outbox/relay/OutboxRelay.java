package com.insurancefraud.outbox.relay;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.insurancefraud.common.config.RabbitMQConfig;
import com.insurancefraud.entity.OutboxEvent;
import com.insurancefraud.enums.OutboxStatus;
import com.insurancefraud.outbox.repository.OutboxEventRepo;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageBuilder;
import org.springframework.amqp.core.MessageProperties;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.amqp.rabbit.connection.CorrelationData;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import java.util.concurrent.TimeUnit;

@Slf4j
@RequiredArgsConstructor
@Component
public class OutboxRelay {
    private final OutboxEventRepo outboxEventRepo;
    private final RabbitTemplate rabbitTemplate;
    private final ObjectMapper objectMapper;

    private static final int MAX_ATTEMPTS = 5;
    private static final int BATCH_SIZE = 20;

    @Value("${rabbitmq.exchange.events}")
    private String exchangeEvents;

    // Runs every 2 seconds (with 1s initial delay on startup)
    @Scheduled(fixedDelay = 2000, initialDelay = 1000)
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public void relayMessages(){

        Instant now = Instant.now();
        List<OutboxEvent> pendingEvents = outboxEventRepo.findPendingEventsForLease(
                now, BATCH_SIZE);

        if (pendingEvents.isEmpty()) {
            return;
        }

        log.debug("Found {} pending outbox event(s) to publish", pendingEvents.size());

        for (OutboxEvent event : pendingEvents) {
             publishEvent(event, now);

        }
    }

    private void publishEvent(OutboxEvent event, Instant now){
        String routingKey = event.getEventType().getRoutingKey();
        try {
            // Set 30-second lease so other workers won't pick this up
            event.setLockedUntil(now.plusSeconds(30));
            event.setStatus(OutboxStatus.PROCESSING);

            CorrelationData correlationData = new CorrelationData(String.valueOf(event.getEventId()));

            Message message = MessageBuilder
                    .withBody(event.getPayload().getBytes(StandardCharsets.UTF_8))
                    .setContentType(MessageProperties.CONTENT_TYPE_JSON)
                    .setContentEncoding(StandardCharsets.UTF_8.name())
                    .setHeader("eventId", event.getEventId())
                    .setHeader("eventType", event.getEventType().name())
                    .build();

            rabbitTemplate.send(exchangeEvents, routingKey, message, correlationData);

            // Await broker publisher confirmation (correlated confirm)
            CorrelationData.Confirm confirm = correlationData.getFuture().get(5, TimeUnit.SECONDS);
            if (confirm == null || !confirm.isAck()) {
                String reason = confirm != null ? confirm.getReason() : "Broker confirmation timed out";
                throw new IllegalStateException("RabbitMQ NACK or timeout for OutboxEvent #" + event.getEventId() + ": " + reason);
            }

            // Check if broker returned message as unroutable (mandatory=true)
            if (correlationData.getReturned() != null) {
                throw new IllegalStateException("RabbitMQ unroutable message returned for OutboxEvent #" + event.getEventId()
                        + " (replyCode=" + correlationData.getReturned().getReplyCode()
                        + ", replyText=" + correlationData.getReturned().getReplyText() + ")");
            }

            // Mark as PUBLISHED only after confirmed broker ACK
            event.setStatus(OutboxStatus.PUBLISHED);
            event.setPublishedAt(Instant.now());
            event.setLockedUntil(null);
            event.setLastError(null);
            log.info("Successfully published and confirmed OutboxEvent #{} [{}] to RabbitMQ",
                    event.getEventId(), routingKey);
        }catch (Exception ex){
            int attempts = event.getAttempts()+1;
            event.setAttempts(attempts);
            event.setLockedUntil(null); // Release the lock so it can be retried

            String errorMsg = ex.getMessage() != null ? ex.getMessage() : ex.getClass().getSimpleName();
            event.setLastError(errorMsg.substring(0, Math.min(errorMsg.length(), 500)));

            if(attempts>=MAX_ATTEMPTS){
                event.setStatus(OutboxStatus.DEAD);
                log.error("OutboxEvent #{} permanently DEAD after {} attempts. Error: {}",
                        event.getEventId(), attempts, errorMsg);
            }else{
                // Exponential backoff: 3^attempts seconds (3s, 9s, 27s, 81s)
                long backoffSeconds = (long) Math.pow(3, attempts);
                event.setNextAttemptAt(now.plusSeconds(backoffSeconds));
                event.setStatus(OutboxStatus.NEW);
                log.warn("Failed to publish OutboxEvent #{}. Retry #{} scheduled in {}s. Error: {}",
                        event.getEventId(), attempts, backoffSeconds, errorMsg);
            }
        }
        outboxEventRepo.save(event);
    }
}