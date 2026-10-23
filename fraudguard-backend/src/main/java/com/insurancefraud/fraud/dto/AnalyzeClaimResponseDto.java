package com.insurancefraud.fraud.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.insurancefraud.enums.RiskLevel;
import lombok.Getter;
import lombok.Setter;
import java.util.List;

@Setter
@Getter
public class AnalyzeClaimResponseDto {
    @JsonProperty("claim_id")
    private Long claimId;

    @JsonProperty("tenant_id")
    private String tenantId;

    @JsonProperty("risk_score")
    private Integer risk_score;

    @JsonProperty("risk_level")
    private RiskLevel risk_level;

    @JsonProperty("recommendation")
    private String recommendation;

    @JsonProperty("summary")
    private String summary;

    @JsonProperty("flags")
    private List<ClaimEvidenceFlagDto> flags;

    @JsonProperty("details")
    private ClaimAnalysisDetailsDto details;
}
