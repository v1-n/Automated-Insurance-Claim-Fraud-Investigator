package com.insurancefraud.investigator.dto;

import com.insurancefraud.enums.ClaimStatus;
import com.insurancefraud.enums.ClaimType;
import com.insurancefraud.enums.FraudStatus;
import lombok.Data;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

@Getter
@Setter
@Data
public class InvestigatorClaimDetailsResponseDto {


    private boolean reviewAllowed;
    private String reviewNotes;

    // Claim Info
    private Long claimId;
    private String claimNumber;
    private ClaimType claimType;
    private BigDecimal claimAmount;
    private ClaimStatus claimStatus;
    private FraudStatus fraudStatus;

    private Instant incidentDate;
    private String incidentCity;
    private String incidentState;
    private String description;
    private Instant updatedAt;
    // Customer Info
    private Long customerId;
    private String customerName;
    private String customerEmail;

    // Documents
    private List<ClaimDocumentResponseDto> documents;

    // Policy Information
    private String policyNumber;
    private String planName;
    private String vehicleNumber;
    private String vehicleMakeModel;
    private BigDecimal insuredDeclaredValue;
    private Instant policyStartDate;
    private Instant policyEndDate;
    private String policyStatus;

    // Audit
    private Instant createdAt;
}
