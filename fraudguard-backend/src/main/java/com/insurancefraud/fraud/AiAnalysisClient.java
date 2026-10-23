package com.insurancefraud.fraud;

import com.insurancefraud.fraud.dto.AnalyzeClaimRequestDto;
import com.insurancefraud.fraud.dto.AnalyzeClaimResponseDto;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Slf4j
@Component
public class AiAnalysisClient {

    @Value("${ai.fraud.service.internal-key}")
    private String internalKey;

    private final RestClient restClient;

    public AiAnalysisClient(RestClient restClient) {
        this.restClient = restClient;
    }

    public AnalyzeClaimResponseDto dispatchToAi(AnalyzeClaimRequestDto requestDto) {
        AnalyzeClaimResponseDto responseDto = restClient.post()
                .header("X-Internal-Key", internalKey)
                .body(requestDto)
                .retrieve()
                .body(AnalyzeClaimResponseDto.class);
        log.info("AI Analysis completed for Claim ID: {}", requestDto.getClaimId());
        return responseDto;
    }
}
