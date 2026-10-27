package com.insurancefraud.admin.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class PaginatedAdminClaimResponseDto {

    private List<AdminClaimSummaryResponseDto> content;

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