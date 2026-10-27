package com.insurancefraud.document.service.impl;

import com.insurancefraud.document.dto.ClaimDocumentsResponseDto;
import com.insurancefraud.document.repository.ClaimDocumentRepo;
import com.insurancefraud.entity.Claim;
import com.insurancefraud.entity.ClaimDocument;
import com.insurancefraud.entity.User;
import com.insurancefraud.enums.ClaimStatus;
import com.insurancefraud.enums.DocumentStatus;
import com.insurancefraud.enums.DocumentType;
import com.insurancefraud.enums.EventType;
import com.insurancefraud.outbox.service.OutboxService;
import com.insurancefraud.storage.dto.StoredFileResult;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.modelmapper.ModelMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class ClaimDocumentWriter {

    private final ClaimDocumentRepo claimDocumentRepo;
    private final ModelMapper mapper;
    private final OutboxService outboxService;

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

        // Emit outbox event ONLY if the claim has already been submitted and is PENDING.
        // During draft creation, files are uploaded before submission; analysis runs at POST /claims/{id}/submit.
        // Crucially, document upload never overwrites fraudStatus (preserving investigator verdicts).
        if (claim.getSubmittedAt() != null && claim.getClaimStatus() == ClaimStatus.PENDING) {
            outboxService.record(
                    EventType.CLAIM_DOCUMENT_ADDED,
                    claim,
                    Map.of(
                            "documentId", claimDocument.getClaimDocId(),
                            "documentType", claimDocument.getDocumentType().name()
                    )
            );
            log.info("Queued outbox event for Claim #{} document upload (EventType: CLAIM_DOCUMENT_ADDED)", claim.getClaimNumber());
        }

        return mapper.map(claimDocument, ClaimDocumentsResponseDto.class);
    }
}
