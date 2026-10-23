package com.insurancefraud.fraud.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;
import java.util.List;

@Setter
@Getter
public class ClaimAnalysisDetailsDto {
    @JsonProperty("total_documents_analyzed")
    private Integer totalDocumentsAnalyzed;

    @JsonProperty("total_photos_analyzed")
    private Integer totalPhotosAnalyzed;

    @JsonProperty("document_summaries")
    private List<DocumentSummaryResultDto> documentSummaries;

    @JsonProperty("photo_hashes")
    private List<PhotoHashResultDto> photoHashes;
}
