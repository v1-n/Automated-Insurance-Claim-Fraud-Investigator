package com.insurancefraud.claim.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class PaginatedClaimResponse {
    private List<ClaimSummaryResponseDto> content;
    private long totalElements;
    private int totalPages;
    private int pageNo;
    private int pageSize;
    private boolean isFirst;
    private boolean isLast;
    private boolean sorted;
    private String sortBy;
    private Long nextPage;
    private Long previousPage;



}
