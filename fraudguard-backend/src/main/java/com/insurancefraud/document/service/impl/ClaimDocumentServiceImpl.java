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
    private  StoredFileResult storedFileResult;


    @Transactional
    @Override
    public ClaimDocumentsResponseDto uploadClaimDocument(Long claimId, MultipartFile file, DocumentType documentType) {
        validateFile(file);
        User user = currentUserService.getCurrentActiveUser();
        Claim claim = claimRepo.findByClaimIdAndIsDeletedFalse(claimId)
                .orElseThrow(() -> new ResourceNotFoundException("Claim not found"));

        if (!claim.getUser().getUserId().equals(user.getUserId())) {
            throw new UnauthorizedException("You cannot upload documents to this claim");
        }
        try{
            storedFileResult= storageService.storeFile(file, claim);
        } catch (IOException e) {
            log.error("File upload failed: {}", e.getMessage());
            throw new FileStorageException("Failed to store file", e);
        }
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
        log.info("Document uploaded successfully for claim {}", claim.getClaimNumber());

        return mapper.map(
                claimDocument,
                ClaimDocumentsResponseDto.class
        );
    }

    @Override
    @Transactional(readOnly = true)
    public List<ClaimDocumentsResponseDto> getClaimDocumentsByClaimId(Long claimId) {

        User user = currentUserService.getCurrentActiveUser();

        Claim claim =
                claimRepo.findByClaimIdAndIsDeletedFalse(claimId).orElseThrow(() ->
                                new ResourceNotFoundException("Claim not found with ID: " + claimId));

        if (!claim.getUser().getUserId().equals(user.getUserId())) {
            throw new UnauthorizedException("You cannot access documents for this claim");
        }

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

        long maxFileSize = 10 * 1024 * 1024;
        if (file.getSize() > maxFileSize) {
            throw new InvalidFileException("File size exceeds 10MB");
        }
    }



}