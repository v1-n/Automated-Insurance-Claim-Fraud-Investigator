
package com.insurancefraud.notification.consumer;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.insurancefraud.entity.Notifications;
import com.insurancefraud.entity.Tenant;
import com.insurancefraud.entity.User;
import com.insurancefraud.entity.UserDevice;
import com.insurancefraud.enums.EventType;
import com.insurancefraud.notification.service.NotificationChannel;
import com.insurancefraud.notification.service.NotificationRecipientResolver;
import com.insurancefraud.repository.NotificationRepo;
import com.insurancefraud.repository.TenantRepo;
import com.insurancefraud.repository.UserDeviceRepo;
import com.insurancefraud.repository.UserRepo;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class PushNotificationConsumer {

    private final ObjectMapper objectMapper;
    private final NotificationChannel notificationChannel;
    private final UserDeviceRepo userDeviceRepo;
    private final NotificationRecipientResolver recipientResolver;
    private final NotificationRepo notificationRepo;
    private final UserRepo userRepo;
    private final TenantRepo tenantRepo;

    @RabbitListener(
            queues = "${rabbitmq.queue.notify.push}",
            concurrency = "2"
    )
    public void consumePushNotification(Message message) {

        try {
            String payloadStr = new String(
                    message.getBody(),
                    StandardCharsets.UTF_8
            );

            JsonNode payload = objectMapper.readTree(payloadStr);

            String routingKey =
                    message.getMessageProperties().getReceivedRoutingKey();

            if (routingKey == null || routingKey.isBlank()) {
                throw new IllegalArgumentException(
                        "Missing RabbitMQ routing key"
                );
            }

            JsonNode tenantNode = payload.get("tenantId");

            if (tenantNode == null
                    || tenantNode.isNull()
                    || !tenantNode.canConvertToLong()
                    || tenantNode.longValue() <= 0) {
                throw new IllegalArgumentException(
                        "Missing or invalid tenantId"
                );
            }

            Long tenantId = tenantNode.longValue();

            Long recipientId =
                    recipientResolver.resolveRecipientId(
                            routingKey, payload
                    );

            // Some events may not have a notification recipient.
            if (recipientId == null) {
                log.info(
                        "No push recipient for event {}. Skipping.",
                        routingKey
                );
                return;
            }

            // Extract eventId from header or JSON envelope
            Long eventId = null;
            Object headerEventId = message.getMessageProperties().getHeader("eventId");
            if (headerEventId instanceof Number n) {
                eventId = n.longValue();
            } else if (payload.has("eventId") && !payload.get("eventId").isNull()) {
                eventId = payload.get("eventId").asLong();
            }

            EventType eventType = null;
            if (payload.hasNonNull("eventType")) {
                try {
                    eventType = EventType.valueOf(payload.get("eventType").asText());
                } catch (Exception ignored) {}
            }

            JsonNode claimNumberNode = payload.get("claimNumber");
            JsonNode claimIdNode = payload.get("claimId");
            Long claimId = (claimIdNode != null && !claimIdNode.isNull() && claimIdNode.canConvertToLong())
                    ? claimIdNode.longValue()
                    : null;

            String claimReference = (claimNumberNode != null && !claimNumberNode.isNull() && !claimNumberNode.asText().isBlank())
                    ? "#" + claimNumberNode.asText()
                    : (claimId != null ? "#" + claimId : "your claim");

            String title;
            String body;

            switch (routingKey) {
                case "claim.submitted" -> {
                    title = "Claim submitted";
                    body = "A new claim has been submitted for review.";
                }
                case "claim.assigned" -> {
                    title = "Claim assigned";
                    body = "Claim " + claimReference
                            + " has been assigned to you for investigation.";
                }
                case "ai.analysis.ready" -> {
                    title = "Claim analysis complete";
                    body = "The AI analysis for claim " + claimReference
                            + " is ready for review.";
                }
                case "claim.approved" -> {
                    title = "Claim approved";
                    body = "Your claim " + claimReference
                            + " has been approved.";
                }
                case "review.submitted" -> {
                    title = "Claim review completed";
                    body = "The investigator has completed the review for claim "
                            + claimReference + ".";
                }
                case "claim.rejected" -> {
                    title = "Claim update";
                    body = "There is an update regarding claim "
                            + claimReference + ". Please check the app.";
                }
                default -> {
                    log.debug(
                            "No push message configured for {}",
                            routingKey
                    );
                    return;
                }
            }

            // 1. Save In-App Notification in DB (with deduplication on eventId + recipientId)
            try {
                if (eventId == null || !notificationRepo.existsByEventIdAndUser_UserId(eventId, recipientId)) {
                    User recipient = userRepo.findById(recipientId).orElse(null);
                    Tenant tenant = tenantRepo.findById(tenantId).orElse(null);

                    if (recipient != null && tenant != null) {
                        Notifications inAppNotification = Notifications.builder()
                                .tenant(tenant)
                                .user(recipient)
                                .title(title)
                                .body(body)
                                .eventType(eventType != null ? eventType : EventType.CLAIM_SUBMITTED)
                                .referenceId(claimId)
                                .eventId(eventId)
                                .read(false)
                                .build();

                        notificationRepo.save(inAppNotification);
                        log.info("Saved in-app notification for recipient {} [{}]", recipientId, routingKey);
                    }
                }
            } catch (Exception ex) {
                log.warn("Could not save in-app notification in DB: {}", ex.getMessage());
            }

            // 2. Dispatch FCM Push Notification to registered mobile devices
            List<UserDevice> devices =
                    userDeviceRepo
                            .findAllByUser_UserIdAndTenant_TenantIdAndActiveTrue(
                                    recipientId, tenantId
                            );

            if (devices.isEmpty()) {
                log.debug(
                        "No active push devices for recipient {} in tenant {}. Push skipped.",
                        recipientId, tenantId
                );
                return;
            }

            for (UserDevice device : devices) {
                notificationChannel.sendNotification(
                        title,
                        body,
                        device.getToken()
                );
            }

            log.info(
                    "Push notification processed for event {}, recipient {}, devices {}",
                    routingKey, recipientId, devices.size()
            );

        } catch (Exception ex) {
            log.error(
                    "Failed to process push notification",
                    ex
            );

            // Propagate failures so the configured listener retry/DLQ
            // policy can handle them.
            throw new IllegalStateException(
                    "Push notification processing failed",
                    ex
            );
        }
    }
}
