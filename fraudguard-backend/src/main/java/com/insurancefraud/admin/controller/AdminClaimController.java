package com.insurancefraud.admin.controller;

import com.insurancefraud.admin.dto.*;
import com.insurancefraud.admin.service.AdminClaimService;
import com.insurancefraud.common.payload.ApiResponse;
import com.insurancefraud.enums.ClaimSortField;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import com.insurancefraud.claim.dto.ClaimSummaryResponseDto;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import com.insurancefraud.entity.ClaimDocument;

@RequestMapping("/api/v1/admin")
@RestController
public class AdminClaimController {

    private final AdminClaimService adminClaimService;

    public AdminClaimController(AdminClaimService adminClaimService) {
        this.adminClaimService = adminClaimService;
    }

    @PatchMapping("/claims/{claimId}/assign-investigator")
    public ResponseEntity<ApiResponse<Void>>
    assignInvestigatorToClaim(
            @PathVariable Long claimId,
            @Valid @RequestBody AssignInvestigatorRequestDto requestDto
    ) {
        adminClaimService.assignInvestigatorToClaim(
                claimId,
                requestDto.getInvestigatorId()
        );

        return ResponseEntity.ok(
                new ApiResponse<>(
                        true,
                        "Claim assigned for investigation",
                        200,
                        Instant.now(),
                        null
                )
        );
    }

    @GetMapping("/investigators/workload")
    public ResponseEntity<ApiResponse<List<InvestigatorsWorkloadResDto>>> getInvestigatorsWorkload() {

        List<InvestigatorsWorkloadResDto> workloadResDtoList =
                adminClaimService.getInvestigatorsWorkload();

        return ResponseEntity.ok(
                new ApiResponse<>(
                        true,
                        "Investigator workload retrieved successfully",
                        200,
                        Instant.now(),
                        workloadResDtoList
                )
        );
    }

    @PatchMapping("/claims/{claimId}/approve")
    public ResponseEntity<ApiResponse<ClaimDecisionResponseDto>> approveClaim(
            @PathVariable Long claimId,
            @Valid @RequestBody ClaimDecisionRequestDto requestDto
    ) {
        ClaimDecisionResponseDto responseDto = adminClaimService.approveClaim(claimId, requestDto);
        return ResponseEntity.ok(
                new ApiResponse<>(
                        true,
                        "Claim approved successfully",
                        200,
                        Instant.now(),
                        responseDto
                )
        );
    }

    @PatchMapping("/claims/{claimId}/reject")
    public ResponseEntity<ApiResponse<ClaimDecisionResponseDto>> rejectClaim(
            @PathVariable Long claimId,
            @Valid @RequestBody ClaimDecisionRequestDto requestDto
    ) {
        ClaimDecisionResponseDto responseDto = adminClaimService.rejectClaim(claimId, requestDto);
        return ResponseEntity.ok(
                new ApiResponse<>(
                        true,
                        "Claim rejected successfully",
                        200,
                        Instant.now(),
                        responseDto
                )
        );
    }

    @GetMapping("/dashboard")
    public ResponseEntity<ApiResponse<DashboardResponseDto>> getAdminDashboard() {
        DashboardResponseDto dashboardData = adminClaimService.getAdminDashboard();
        return ResponseEntity.ok(
                new ApiResponse<>(
                        true,
                        "Dashboard data retrieved successfully",
                        200,
                        Instant.now(),
                        dashboardData
                )
        );
    }

    @GetMapping("/claims/unassigned")
    public ResponseEntity<ApiResponse<List<ClaimSummaryResponseDto>>> getUnassignedClaims() {
        List<ClaimSummaryResponseDto> claims = adminClaimService.getUnassignedClaimsForTenant();
        return ResponseEntity.ok(new ApiResponse<>(true, "Unassigned claims retrieved", 200, Instant.now(), claims));
    }

    @GetMapping("/claims")
    public ResponseEntity<ApiResponse<PaginatedAdminClaimResponseDto>> getAllClaims(
            @RequestParam(defaultValue = "0") int pageNumber,
            @RequestParam(defaultValue = "10") int pageSize,
            @RequestParam(defaultValue = "CREATED_AT") ClaimSortField sortBy,
            @RequestParam(defaultValue = "DESC") String sortDir
    ) {

        PaginatedAdminClaimResponseDto data =
                adminClaimService.getAllClaims(
                        pageNumber,
                        pageSize,
                        sortBy,
                        sortDir
                );

        return ResponseEntity.ok(
                new ApiResponse<>(
                        true,
                        "Claims retrieved successfully",
                        HttpStatus.OK.value(),
                        Instant.now(),
                        data
                )
        );
    }

    @GetMapping("/claims/{claimId}")
    public ResponseEntity<ApiResponse<com.insurancefraud.claim.dto.ClaimDetailResponseDto>> getClaimById(
            @PathVariable Long claimId
    ) {
        com.insurancefraud.claim.dto.ClaimDetailResponseDto data = adminClaimService.getClaimById(claimId);
        return ResponseEntity.ok(
                new ApiResponse<>(
                        true,
                        "Claim details retrieved successfully",
                        HttpStatus.OK.value(),
                        Instant.now(),
                        data
                )
        );
    }

    @GetMapping("/claims/{claimId}/documents")
    public ResponseEntity<ApiResponse<List<com.insurancefraud.document.dto.ClaimDocumentsResponseDto>>> getClaimDocuments(
            @PathVariable Long claimId
    ) {
        List<com.insurancefraud.document.dto.ClaimDocumentsResponseDto> data = adminClaimService.getClaimDocuments(claimId);
        return ResponseEntity.ok(
                new ApiResponse<>(
                        true,
                        "Claim documents retrieved successfully",
                        HttpStatus.OK.value(),
                        Instant.now(),
                        data
                )
        );
    }

    @GetMapping("/documents/{documentId}/download")
    public ResponseEntity<Resource> downloadDocument(
            @PathVariable Long documentId
    ) {
        ClaimDocument document = adminClaimService.getClaimDocumentById(documentId);
        Resource resource = adminClaimService.downloadDocument(documentId);

        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(document.getMimeType()))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + document.getOriginalFileName() + "\"")
                .contentLength(document.getFileSize())
                .body(resource);
    }


}


