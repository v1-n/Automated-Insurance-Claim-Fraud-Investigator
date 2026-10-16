package com.insurancefraud.investigator.controller;

import com.insurancefraud.common.exception.ResourceNotFoundException;
import com.insurancefraud.common.payload.ApiResponse;
import com.insurancefraud.document.repository.ClaimDocumentRepo;
import com.insurancefraud.entity.ClaimDocument;
import com.insurancefraud.enums.ClaimSortField;
import com.insurancefraud.investigator.dto.*;
import com.insurancefraud.investigator.service.InvestigatorClaimService;
import jakarta.validation.Valid;
import org.springframework.core.io.Resource;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.*;
import com.insurancefraud.storage.service.StorageService;

import java.time.Instant;

@RequestMapping("/api/v1/investigator")
@RestController
public class InvestigatorClaimController {

    private final InvestigatorClaimService investigatorClaimService;
    private final ClaimDocumentRepo claimDocumentRepo;
    private final StorageService storageService;

    public InvestigatorClaimController(InvestigatorClaimService investigatorClaimService,ClaimDocumentRepo claimDocumentRepo, StorageService storageService) {
        this.investigatorClaimService = investigatorClaimService;
        this.claimDocumentRepo =claimDocumentRepo;
        this.storageService = storageService;
    }


    @GetMapping("/claims")
    public ResponseEntity<ApiResponse<PaginatedInvestigatorClaimResponseDto>> getAssignedClaims(
            @RequestParam(defaultValue = "0") int pageNumber,
            @RequestParam(defaultValue = "10") int pageSize,
            @RequestParam(defaultValue = "CREATED_AT") ClaimSortField sortBy,
            @RequestParam(defaultValue = "DESC") String sortDir
    ) {

        PaginatedInvestigatorClaimResponseDto data =
                investigatorClaimService.getAssignedClaimsForInvestigator(
                        pageNumber,
                        pageSize,
                        sortBy,
                        sortDir
                );

        return ResponseEntity.ok(
                new ApiResponse<>(
                        true,
                        "Assigned claims retrieved successfully",
                        200,
                        Instant.now(),
                        data
                )
        );
    }

    @PatchMapping("/claims/{claimId}/review")
    public ResponseEntity<ApiResponse<InvestigatorClaimReviewResponseDto>> reviewClaim(
            @PathVariable Long claimId,
            @Valid
            @RequestBody InvestigatorClaimReviewRequestDto requestDto
    ) {
        InvestigatorClaimReviewResponseDto reviewResponseDto =
                investigatorClaimService.reviewClaimById(
                        claimId,
                        requestDto
                );
        ApiResponse<InvestigatorClaimReviewResponseDto> response =
                new ApiResponse<>(
                        true,
                        "Claim reviewed successfully",
                        200,
                        Instant.now(),
                        reviewResponseDto
                );

        return ResponseEntity.ok(response);
    }

    @GetMapping("/claims/{claimId}")
    public ResponseEntity<ApiResponse<InvestigatorClaimDetailsResponseDto>>
    getClaimDetails(
            @PathVariable Long claimId
    ) {
        InvestigatorClaimDetailsResponseDto claimDetails =
                investigatorClaimService.getClaimDetails(claimId);
        return ResponseEntity.ok(
                new ApiResponse<>(
                        true,
                        "Claim details retrieved successfully",
                        200,
                        Instant.now(),
                        claimDetails
                )
        );


    }

    @GetMapping("/documents/{claimDocId}/view")
    public ResponseEntity<Resource> viewDocument(
            @PathVariable Long claimDocId
    ) {

        ClaimDocument document =
                claimDocumentRepo
                        .findByClaimDocIdAndIsDeletedFalse(claimDocId)
                        .orElseThrow(() ->
                                new ResourceNotFoundException("Document not found"));

        Resource resource = storageService.downloadFile(document.getFileUrl());
        
        String mimeType = document.getMimeType();
        if (mimeType == null || mimeType.isBlank()) {
            mimeType = "application/octet-stream";
        }

        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(mimeType))
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + document.getOriginalFileName() + "\"")
                .contentLength(document.getFileSize())
                .body(resource);
    }
}

