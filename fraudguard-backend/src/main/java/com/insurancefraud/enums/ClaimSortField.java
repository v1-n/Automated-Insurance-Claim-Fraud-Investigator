package com.insurancefraud.enums;

public enum ClaimSortField {

    CREATED_AT("createdAt"),

    CLAIM_AMOUNT("claimAmount"),

    INCIDENT_DATE("incidentDate"),

    CLAIM_STATUS("claimStatus");

    private final String fieldName;

    ClaimSortField(String fieldName) {
        this.fieldName = fieldName;
    }

    public String getFieldName() {
        return fieldName;
    }
}