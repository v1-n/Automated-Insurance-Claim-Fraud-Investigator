package com.insurancefraud;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

// @SpringBootTest
class fraudGuardBackendApplicationTests {

    @Test
    void testModelMapperStrictStrategy() {
        org.modelmapper.ModelMapper mapper = new org.modelmapper.ModelMapper();
        mapper.getConfiguration().setMatchingStrategy(org.modelmapper.convention.MatchingStrategies.STRICT);
        com.insurancefraud.entity.Claim claim = new com.insurancefraud.entity.Claim();
        claim.setClaimId(1L);
        claim.setClaimNumber("CLM-123");
        claim.setIncidentDate(java.time.Instant.now());
        claim.setCreatedAt(java.time.Instant.now());
        claim.setUpdatedAt(java.time.Instant.now());

        com.insurancefraud.claim.dto.ClaimDetailResponseDto dto = mapper.map(claim, com.insurancefraud.claim.dto.ClaimDetailResponseDto.class);
        org.junit.jupiter.api.Assertions.assertEquals(1L, dto.getClaimId());
    }

}
