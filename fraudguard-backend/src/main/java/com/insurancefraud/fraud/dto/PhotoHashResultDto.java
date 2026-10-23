package com.insurancefraud.fraud.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
public class PhotoHashResultDto {
    @JsonProperty("claim_doc_id")
    private Long claimDocId;

    @JsonProperty("phash")
    private String phash;
}
