package com.insurancefraud.investigator.service;

import com.insurancefraud.enums.ClaimSortField;
import com.insurancefraud.investigator.dto.*;

import java.util.List;

public interface InvestigatorClaimService {
    PaginatedInvestigatorClaimResponseDto getAssignedClaimsForInvestigator(
            int pageNumber,
            int pageSize,
            ClaimSortField sortBy,
            String sortDir
    );

    InvestigatorClaimReviewResponseDto reviewClaimById(Long claimId, InvestigatorClaimReviewRequestDto requestDto);

    InvestigatorClaimDetailsResponseDto getClaimDetails(Long claimId);
}
