package com.insurancefraud.document.service.impl;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.insurancefraud.claim.repository.ClaimRepo;
import com.insurancefraud.document.dto.ClaimDocumentsResponseDto;
import com.insurancefraud.document.repository.ClaimDocumentRepo;
import com.insurancefraud.entity.Claim;
import com.insurancefraud.entity.ClaimDocument;
import com.insurancefraud.entity.OutboxEvent;
import com.insurancefraud.entity.User;
import com.insurancefraud.enums.AggregateType;
import com.insurancefraud.enums.ClaimStatus;
import com.insurancefraud.enums.DocumentStatus;
import com.insurancefraud.enums.DocumentType;
import com.insurancefraud.enums.EventType;
import com.insurancefraud.enums.FraudStatus;
import com.insurancefraud.enums.OutboxStatus;
import com.insurancefraud.outbox.repository.OutboxEventRepo;
import com.insurancefraud.storage.dto.StoredFileResult;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.modelmapper.ModelMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class ClaimDocumentWriter {

    private final ClaimDocumentRepo claimDocumentRepo;
    private final ClaimRepo claimRepo;
    private final ModelMapper mapper;
    private final OutboxEventRepo outboxEventRepo;
    private final ObjectMapper objectMapper;

    @Transactional
    public ClaimDocumentsResponseDto saveDocumentRecord(Claim claim, User user, StoredFileResult storedFileResult, DocumentType documentType) {
        ClaimDocument claimDocument = new ClaimDocument();
        claimDocument.setTenant(user.getTenant());
        claimDocument.setClaim(claim);
        claimDocument.setUploadedBy(user);
        claimDocument.setDocumentType(documentType);
        claimDocument.setFileName(storedFileResult.getStorageKey());
        claimDocument.setOriginalFileName(storedFileResult.getOriginalName());
        claimDocument.setFileUrl(storedFileResult.getFileUrl());
        claimDocument.setStorageProvider(storedFileResult.getProvider());
        claimDocument.setMimeType(storedFileResult.getMimeType());
        claimDocument.setFileSize(storedFileResult.getFileSize());
        claimDocument.setDocumentStatus(DocumentStatus.ACTIVE);
        claimDocument = claimDocumentRepo.save(claimDocument);

        log.info("Document recorded in DB successfully for claim {}", claim.getClaimNumber());

        // Whenever evidence (FIR, accident photo, etc.) is uploaded,
        // trigger background AI analysis via Outbox + RabbitMQ
        if (claim.getClaimStatus() != ClaimStatus.REJECTED) {
            claim.setFraudStatus(FraudStatus.PENDING_ANALYSIS);
            claimRepo.save(claim);

            Map<String, Object> payloadMap = Map.of(
                    "claimId", claim.getClaimId(),
                    "claimNumber", claim.getClaimNumber(),
                    "tenantId", claim.getTenant().getTenantId(),
                    "documentId", claimDocument.getClaimDocId(),
                    "documentType", claimDocument.getDocumentType().name()
            );

            try {
                String payloadJson = objectMapper.writeValueAsString(payloadMap);
                OutboxEvent outboxEvent = new OutboxEvent();
                outboxEvent.setTenant(claim.getTenant());
                outboxEvent.setEventType(EventType.CLAIM_DOCUMENT_ADDED);
                outboxEvent.setAggregateType(AggregateType.CLAIM);
                outboxEvent.setAggregateId(claim.getClaimId());
                outboxEvent.setPayload(payloadJson);
                outboxEvent.setStatus(OutboxStatus.NEW);
                outboxEvent.setAttempts(0);
                outboxEvent.setNextAttemptAt(Instant.now());
                outboxEventRepo.save(outboxEvent);
                log.info("Queued outbox event for Claim #{} document upload (EventType: CLAIM_DOCUMENT_ADDED)", claim.getClaimNumber());
            } catch (Exception e) {
                log.error("Failed to serialize outbox payload for uploaded document: {}", e.getMessage(), e);
            }
        }

        return mapper.map(claimDocument, ClaimDocumentsResponseDto.class);
    }
}
