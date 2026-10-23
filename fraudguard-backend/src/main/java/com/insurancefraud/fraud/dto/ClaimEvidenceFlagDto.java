package com.insurancefraud.fraud.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.insurancefraud.enums.Severity;
import lombok.Getter;
import lombok.Setter;
import java.util.List;

@Setter
@Getter
public class ClaimEvidenceFlagDto {
    @JsonProperty("flag_id")
    private String flagId;

    @JsonProperty("code")
    private String code;

    @JsonProperty("category")
    private String category;

    @JsonProperty("severity")
    private Severity severity;

    @JsonProperty("source")
    private String source;

    @JsonProperty("explanation")
    private String explanation;

    @JsonProperty("benign_explanations")
    private List<String> benignExplanations;

    @JsonProperty("next_steps")
    private List<String> nextSteps;

    @JsonProperty("confidence")
    private Double confidence;
}
