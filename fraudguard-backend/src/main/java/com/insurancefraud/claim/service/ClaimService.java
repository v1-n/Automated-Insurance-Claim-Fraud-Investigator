package com.insurancefraud.claim.service;


import com.insurancefraud.claim.dto.ClaimDetailResponseDto;
import com.insurancefraud.claim.dto.ClaimRequestDto;
import com.insurancefraud.claim.dto.ClaimSummaryResponseDto;
import com.insurancefraud.claim.dto.PaginatedClaimResponse;
import com.insurancefraud.enums.ClaimSortField;
import jakarta.validation.Valid;

public interface ClaimService {
    ClaimSummaryResponseDto createClaim(@Valid ClaimRequestDto requestDto);
    PaginatedClaimResponse getClaimsForCurrentUser(int pageNumber, int pageSize, ClaimSortField sortBy, String sortDir);

    ClaimDetailResponseDto getClaimById(Long claimId);
}
