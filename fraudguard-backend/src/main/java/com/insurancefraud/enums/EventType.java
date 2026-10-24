package com.insurancefraud.enums;

public enum EventType {
    CLAIM_SUBMITTED("claim.submitted"),
    CLAIM_DOCUMENT_ADDED("claim.document.added"),
    CLAIM_ASSIGNED("claim.assigned"),
    REVIEW_SUBMITTED("review.submitted"),
    CLAIM_APPROVED("claim.approved"),
    CLAIM_REJECTED("claim.rejected"),
    AI_ANALYSIS_RERUN_REQUESTED("claim.analysis.rerun"),// admin pressed "re-run analysis"
    AI_ANALYSIS_READY("ai.analysis.ready"),
    AI_ANALYSIS_FAILED("ai.analysis.failed");

    private final String routingKey;
    EventType(String routingKey) { this.routingKey = routingKey; }
    public String routingKey() { return routingKey; }
    public String getRoutingKey() { return routingKey; }
}