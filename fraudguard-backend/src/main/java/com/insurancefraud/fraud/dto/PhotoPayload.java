package com.insurancefraud.fraud.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;


public record PhotoPayload(
        @JsonProperty("claim_doc_id") long claimDocId,
        @JsonProperty("photo_url") String photoUrl,
        @JsonProperty("existing_hashes") List<String> existingHashes
) {}