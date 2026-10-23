package com.insurancefraud.fraud.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.insurancefraud.enums.DocumentType;

public record DocumentPayload(
        @JsonProperty("claim_doc_id") long claimDocId,
        @JsonProperty("document_type") DocumentType documentType,
        @JsonProperty("document_url") String documentUrl
) {}