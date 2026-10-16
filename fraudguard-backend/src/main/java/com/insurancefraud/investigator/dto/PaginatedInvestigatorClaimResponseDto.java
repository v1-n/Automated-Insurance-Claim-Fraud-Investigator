package com.insurancefraud.investigator.dto;


import lombok.Data;
import lombok.Getter;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@Data
public class PaginatedInvestigatorClaimResponseDto {

    private List<InvestigatorClaimResponseDto> content;

    private long totalElements;

    private int totalPages;

    private int pageNo;

    private int pageSize;

    private boolean first;

    private boolean last;

    private boolean sorted;

    private String sortBy;

    private Long nextPage;

    private Long previousPage;
}