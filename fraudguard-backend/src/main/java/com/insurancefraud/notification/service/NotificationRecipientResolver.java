package com.insurancefraud.notification.service;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.stereotype.Component;

@Component
public class NotificationRecipientResolver {

    public Long resolveRecipientId(
            String routingKey,
            JsonNode payload
    ) {
        String field = switch (routingKey) {
            case "claim.assigned",
                 "ai.analysis.ready" -> "investigatorId";

            case "claim.submitted",
                 "review.submitted",
                 "claim.approved",
                 "claim.rejected" -> "customerId";

            default -> null;
        };

        if (field == null) {
            return null;
        }

        JsonNode recipient = payload.get(field);

        if (recipient == null
                || recipient.isNull()
                || !recipient.canConvertToLong()) {
            return null;
        }

        long id = recipient.longValue();
        return id > 0 ? id : null;
    }
}