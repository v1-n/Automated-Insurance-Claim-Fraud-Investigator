package com.insurancefraud.fraud.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.math.BigDecimal;
import java.time.Instant;

public record ClaimGroundTruth(
        @JsonProperty("vehicle_number") String vehicleNumber,
        @JsonProperty("policy_number") String policyNumber,
        @JsonProperty("policy_start_date") String policyStartDate,
        @JsonProperty("policy_end_date") String policyEndDate,
        @JsonProperty("idv_amount") BigDecimal insuredDeclaredValue, // <-- Maps to "idv_amount" for Python
        @JsonProperty("incident_date") String incidentDate,
        @JsonProperty("incident_city") String incidentCity,
        @JsonProperty("incident_state") String incidentState,
        @JsonProperty("incident_latitude") Double incidentLatitude,
        @JsonProperty("incident_longitude") Double incidentLongitude
) {}
