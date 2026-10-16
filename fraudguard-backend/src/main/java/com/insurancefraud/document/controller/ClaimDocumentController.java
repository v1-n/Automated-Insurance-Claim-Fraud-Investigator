package com.insurancefraud.document.controller;

import com.insurancefraud.document.dto.ClaimDocumentsResponseDto;
import com.insurancefraud.entity.ClaimDocument;
import com.insurancefraud.enums.DocumentType;
import com.insurancefraud.common.payload.ApiResponse;
import com.insurancefraud.document.service.ClaimDocumentService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.util.List;

@RestController
@RequiredArgsConstructor
public class ClaimDocumentController {

    private final ClaimDocumentService claimDocumentService;


    @PostMapping("/api/v1/claims/{claimId}/documents")
    public ResponseEntity<ApiResponse<ClaimDocumentsResponseDto>> uploadClaimDocument(
            @PathVariable Long claimId,
            @RequestParam("file") MultipartFile file,
            @RequestParam("documentType") DocumentType documentType
    ) {

        ClaimDocumentsResponseDto data = claimDocumentService.uploadClaimDocument(claimId, file, documentType);

        ApiResponse<ClaimDocumentsResponseDto> response =
                new ApiResponse<>(
                        true,
                        "Document uploaded successfully",
                        HttpStatus.CREATED.value(),
                        Instant.now(),
                        data
                );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(response);
    }

    @GetMapping("/api/v1/claims/{claimId}/documents")
    public ResponseEntity<ApiResponse<List<ClaimDocumentsResponseDto>>> getClaimDocuments(
            @PathVariable Long claimId
    ) {

        List<ClaimDocumentsResponseDto> data = claimDocumentService.getClaimDocumentsByClaimId(claimId);

        ApiResponse<List<ClaimDocumentsResponseDto>> response =
                new ApiResponse<>(
                        true,
                        "Documents retrieved successfully",
                        HttpStatus.OK.value(),
                        Instant.now(),
                        data
                );

        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/api/v1/documents/{documentId}")
    public ResponseEntity<ApiResponse<Void>> deleteClaimDocument(
            @PathVariable Long documentId
    ) {
        claimDocumentService.deleteClaimDocument(documentId);
        ApiResponse<Void> response =
                new ApiResponse<>(
                        true,
                        "Document deleted successfully",
                        HttpStatus.OK.value(),
                        Instant.now(),
                        null
                );

        return ResponseEntity.ok(response);
    }

    @GetMapping("/api/v1/documents/{documentId}/download")
    public ResponseEntity<Resource>
    downloadDocument(
            @PathVariable Long documentId
    ) {
        ClaimDocument document =claimDocumentService.getClaimDocumentById(documentId);
        Resource resource = claimDocumentService.downloadDocument(documentId);

        return ResponseEntity.ok()
                .contentType(
                        MediaType.parseMediaType(
                                document.getMimeType()
                        )
                )
                .header(
                        HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=\""
                                + document.getOriginalFileName()
                                + "\""
                )
                .contentLength(document.getFileSize())
                .body(resource);
    }
}
