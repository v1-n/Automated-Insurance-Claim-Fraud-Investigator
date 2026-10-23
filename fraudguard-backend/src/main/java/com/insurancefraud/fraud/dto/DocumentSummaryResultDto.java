package com.insurancefraud.fraud.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
public class DocumentSummaryResultDto {
    @JsonProperty("claim_doc_id")
    private Long claimDocId;

    @JsonProperty("document_type")
    private String documentType;

    @JsonProperty("vehicle_verified")
    private Boolean vehicleVerified;

    @JsonProperty("text_length")
    private Integer textLength;
}
