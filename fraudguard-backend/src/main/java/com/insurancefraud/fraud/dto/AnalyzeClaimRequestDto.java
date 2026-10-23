package com.insurancefraud.fraud.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.List;

@Getter
@Setter
public class AnalyzeClaimRequestDto {

    @JsonProperty("tenant_id")
    private Long tenantId;

    @JsonProperty("claim_id")
    private Long claimId;

    @JsonProperty("claim_number")
    private String claimNumber;

    @JsonProperty("claim_amount")
    private BigDecimal claimAmount;

    @JsonProperty("ground_truth")
    private ClaimGroundTruth claimGroundTruth;

    @JsonProperty("documents")
    private List<DocumentPayload> documents;

    @JsonProperty("photos")
    private List<PhotoPayload> photos;
}