package com.insurancefraud.fraud.consumer;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.insurancefraud.fraud.service.FraudAnalysisService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class ClaimAnalysisConsumer {
    private final FraudAnalysisService fraudAnalysisService;
    private final ObjectMapper objectMapper;

    @RabbitListener(queues = "${rabbitmq.queue.claim.analysis}", concurrency = "2")
    public void consumeClaimAnalysisJob(String payload){
        try {
            log.info("Received claim analysis job from RabbitMQ: {}", payload);
            JsonNode  jsonNode = objectMapper.readTree(payload);
            Long claimId = jsonNode.get("claimId").asLong();

            // Invoke Python AI Microservice, save risk score & evidence flags to DB
            fraudAnalysisService.analyzeClaimAsync(claimId);
            log.info("AI Analysis completed successfully for Claim ID: {}", claimId);

        }catch (Exception ex){
            log.error("Failed to process claim analysis job: {}. Error: {}", payload, ex.getMessage(), ex);
            throw new RuntimeException(ex);
        }
    }
}
