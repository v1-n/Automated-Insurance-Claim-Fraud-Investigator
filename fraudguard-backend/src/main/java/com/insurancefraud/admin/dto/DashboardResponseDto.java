package com.insurancefraud.admin.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
@AllArgsConstructor
public class DashboardResponseDto {
    private Long totalClaims;
    private Long pendingClaims;
    private Long approvedClaims;
    private Long rejectedClaims;
    private Long suspectedFraudClaims;
    private Long underReviewClaims;
    private Long confirmedFraudClaims;
    private Long clearClaims;
    private Long activeClaims;


}
