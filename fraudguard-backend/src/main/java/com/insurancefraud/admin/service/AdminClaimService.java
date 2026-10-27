package com.insurancefraud.admin.service;

import com.insurancefraud.admin.dto.*;
import com.insurancefraud.enums.ClaimSortField;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import java.util.List;

public interface AdminClaimService {
    void assignInvestigatorToClaim(@Valid Long claimId, @NotNull(message = "Investigator ID cannot be null") Long investigatorId);

    List<InvestigatorsWorkloadResDto> getInvestigatorsWorkload();

    ClaimDecisionResponseDto approveClaim(Long claimsId, ClaimDecisionRequestDto requestDto);

    ClaimDecisionResponseDto rejectClaim(Long claimId, @Valid ClaimDecisionRequestDto requestDto);

    DashboardResponseDto getAdminDashboard();

    List<AdminClaimSummaryResponseDto> getUnassignedClaimsForTenant();

    PaginatedAdminClaimResponseDto getAllClaims(
            int pageNumber,
            int pageSize,
            ClaimSortField sortBy,
            String sortDir
    );

    AdminClaimDetailResponseDto getClaimById(Long claimId);

    List<com.insurancefraud.document.dto.ClaimDocumentsResponseDto> getClaimDocuments(Long claimId);

    org.springframework.core.io.Resource downloadDocument(Long documentId);

    com.insurancefraud.entity.ClaimDocument getClaimDocumentById(Long documentId);

    void rerunAiAnalysis(Long claimId);
}
