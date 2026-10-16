package com.insurancefraud.claim.controller;

import com.insurancefraud.claim.dto.ClaimDetailResponseDto;
import com.insurancefraud.claim.dto.ClaimRequestDto;
import com.insurancefraud.claim.dto.ClaimSummaryResponseDto;
import com.insurancefraud.claim.dto.PaginatedClaimResponse;
import com.insurancefraud.enums.ClaimSortField;
import com.insurancefraud.common.payload.ApiResponse;
import com.insurancefraud.claim.service.ClaimService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;

@Slf4j
@RestController
@RequiredArgsConstructor
@Tag(name = "ClaimController", description = "Endpoints for managing insurance claims")
@RequestMapping("/api/v1/claims")
public class ClaimController {

    private final ClaimService claimService;

    @Operation(summary = "Create a new insurance claim", description = "Allows users to submit a new insurance claim with all necessary details.")
    @PostMapping
    public ResponseEntity<ApiResponse<ClaimSummaryResponseDto>> createClaim(@Valid @RequestBody ClaimRequestDto requestDto) {
        ClaimSummaryResponseDto claimResponse = claimService.createClaim(requestDto);

        ApiResponse<ClaimSummaryResponseDto> response = new ApiResponse<>(
                true,
                "Claim created successfully",
                201,
                Instant.now(),
                claimResponse
        );
        return ResponseEntity.ok(response);
    }

    @GetMapping("/my")
    public ResponseEntity<ApiResponse<PaginatedClaimResponse>> getMyClaims(
            @RequestParam(defaultValue = "0") int pageNumber,
            @RequestParam(defaultValue = "10") int pageSize,
            @RequestParam(defaultValue = "CREATED_AT") ClaimSortField sortBy,
            @RequestParam(defaultValue = "DESC") String sortDir
    ) {
        PaginatedClaimResponse data =
                claimService.getClaimsForCurrentUser(
                        pageNumber,
                        pageSize,
                        sortBy,
                        sortDir
                );

          ApiResponse<PaginatedClaimResponse> response =
                new ApiResponse<>(
                        true,
                        "Claims retrieved successfully",
                        200,
                        Instant.now(),
                        data
                );
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{claimId}")
    public ResponseEntity<ApiResponse<ClaimDetailResponseDto>> getClaimById(@PathVariable Long claimId) {
        ClaimDetailResponseDto claimResponse = claimService.getClaimById(claimId);

        ApiResponse<ClaimDetailResponseDto> response = new ApiResponse<>(
                true,
                "Claim retrieved successfully",
                200,
                Instant.now(),
                claimResponse
        );
        return ResponseEntity.ok(response);
    }

}
