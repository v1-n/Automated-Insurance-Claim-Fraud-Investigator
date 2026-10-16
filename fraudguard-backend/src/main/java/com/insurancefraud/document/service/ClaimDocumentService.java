package com.insurancefraud.document.service;

import com.insurancefraud.document.dto.ClaimDocumentsResponseDto;
import com.insurancefraud.entity.ClaimDocument;
import com.insurancefraud.enums.DocumentType;
import org.springframework.core.io.Resource;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

public interface ClaimDocumentService {

    ClaimDocumentsResponseDto uploadClaimDocument(
            Long claimId,
            MultipartFile file,
            DocumentType documentType
    );

    List<ClaimDocumentsResponseDto> getClaimDocumentsByClaimId(Long claimId);

    ClaimDocument getClaimDocumentById(Long documentId);

    void deleteClaimDocument(Long documentId);

    Resource downloadDocument(Long documentId);
}