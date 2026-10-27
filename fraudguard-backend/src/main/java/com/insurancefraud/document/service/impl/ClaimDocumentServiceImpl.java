package com.insurancefraud.document.service.impl;

import com.insurancefraud.claim.repository.ClaimRepo;
import com.insurancefraud.common.exception.*;
import com.insurancefraud.common.security.CurrentUserService;
import com.insurancefraud.document.dto.ClaimDocumentsResponseDto;
import com.insurancefraud.document.repository.ClaimDocumentRepo;
import com.insurancefraud.document.service.ClaimDocumentService;
import com.insurancefraud.entity.Claim;
import com.insurancefraud.entity.ClaimDocument;
import com.insurancefraud.entity.User;
import com.insurancefraud.enums.DocumentStatus;
import com.insurancefraud.enums.DocumentType;
import com.insurancefraud.enums.StorageProvider;
import com.insurancefraud.enums.SupportedDocumentType;
import com.insurancefraud.storage.dto.StoredFileResult;
import com.insurancefraud.storage.service.StorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.modelmapper.ModelMapper;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class ClaimDocumentServiceImpl implements ClaimDocumentService {

    private final CurrentUserService currentUserService;
    private final StorageService storageService;
    private final ClaimRepo claimRepo;
    private final ClaimDocumentRepo claimDocumentRepo;
    private final ModelMapper mapper;
    private final ClaimDocumentWriter claimDocumentWriter;

    @Override
    public ClaimDocumentsResponseDto uploadClaimDocument(Long claimId, MultipartFile file, DocumentType documentType) {
        validateFile(file);
        User user = currentUserService.getCurrentActiveUser();
        
        // Ownership and tenant validation
        Claim claim = claimRepo.findByUserAndClaimIdAndTenantAndIsDeletedFalse(user, claimId, user.getTenant())
                .orElseThrow(() -> new ResourceNotFoundException("Claim not found or access denied"));

        // Slow network upload happens outside any DB transaction
        StoredFileResult storedFileResult;
        try {
            storedFileResult = storageService.storeFile(file, claim);
        } catch (IOException e) {
            log.error("File upload failed: {}", e.getMessage());
            throw new FileStorageException("Failed to store file", e);
        }

        // Fast isolated transactional write
        return claimDocumentWriter.saveDocumentRecord(claim, user, storedFileResult, documentType);
    }

    @Override
    @Transactional(readOnly = true)
    public List<ClaimDocumentsResponseDto> getClaimDocumentsByClaimId(Long claimId) {

        User user = currentUserService.getCurrentActiveUser();

        Claim claim = claimRepo.findByUserAndClaimIdAndTenantAndIsDeletedFalse(user, claimId, user.getTenant())
                .orElseThrow(() -> new ResourceNotFoundException("Claim not found or access denied"));

        log.info("Retrieving documents for claim {}", claim.getClaimNumber());
        List<ClaimDocument> claimDocuments = claimDocumentRepo.findByClaim_ClaimIdAndIsDeletedFalse(claimId);

        return claimDocuments.stream()
                .map(doc ->
                        mapper.map(
                                doc,
                                ClaimDocumentsResponseDto.class
                        )
                )
                .toList();
    }

    @Override
    public ClaimDocument getClaimDocumentById(Long documentId) {
        User user = currentUserService.getCurrentActiveUser();
        return claimDocumentRepo.findByClaim_User_UserIdAndClaimDocIdAndIsDeletedFalse(user.getUserId(), documentId).orElseThrow(() ->
                new ResourceNotFoundException("Document not found with ID: " + documentId));
    }

    @Transactional
    @Override
    public void deleteClaimDocument(Long documentId) {
        User user = currentUserService.getCurrentActiveUser();;
        ClaimDocument document = claimDocumentRepo
                        .findByClaim_User_UserIdAndClaimDocIdAndIsDeletedFalse(user.getUserId(), documentId)
                        .orElseThrow(() ->
                                new ResourceNotFoundException("Document not found with ID: " + documentId));

        document.setDeleted(true);
        document.setDeletedAt(Instant.now());
        document.setDocumentStatus(DocumentStatus.DELETED);
        document.setUpdatedAt(Instant.now());
        claimDocumentRepo.save(document);
        log.info("Document {} soft deleted by user {}", document.getOriginalFileName(), user.getEmail());
    }

    @Override
    @Transactional(readOnly = true)
    public Resource downloadDocument(Long documentId) {

        User user = currentUserService.getCurrentActiveUser();
        ClaimDocument document = claimDocumentRepo
                .findByClaim_User_UserIdAndClaimDocIdAndIsDeletedFalse(user.getUserId(), documentId)
                        .orElseThrow(() ->
                                new ResourceNotFoundException("Document not found with ID: " + documentId));

        Resource resource;
        try {
            resource = storageService.downloadFile(document.getFileUrl());
        } catch (Exception e) {
            log.error("File download failed: {}", e.getMessage());
            throw new FileStorageException("Failed to download file", e);
        }
        log.info("Document {} downloaded by user {}", document.getOriginalFileName(), user.getEmail());
        return resource;
    }

    private void validateFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new EmptyFileException("File is empty");
        }
        String mimeType = file.getContentType();

        if (mimeType == null || !SupportedDocumentType.isValidMimeType(mimeType)) {
            throw new InvalidMimeTypeException("Unsupported file type");
        }

        long maxFileSize = 10 * 1024 * 1024; // 10MB
        if (file.getSize() > maxFileSize) {
            throw new InvalidFileException("File size exceeds 10MB limit. Please upload a file smaller than 10MB.");
        }
    }



}