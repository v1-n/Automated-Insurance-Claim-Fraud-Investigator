package com.insurancefraud.entity;
import com.insurancefraud.enums.ClaimStatus;
import com.insurancefraud.enums.ClaimType;
import com.insurancefraud.enums.FraudStatus;
import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;

@Getter
@Setter
@Table(name = "claims")
@Entity
public class Claim {

    @Id
    @Column(name = "claim_id",nullable = false)
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long claimId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tenant_id",nullable = false)
    private Tenant tenant;

    @ManyToOne
    @JoinColumn(name = "user_id",nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "assigned_investigator_id")
    private User assignedInvestigator;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "policy_id")
    private Policy policy;

    @Column(name = "claim_number",nullable = false,unique = true)
    private String claimNumber;

    @Column(name = "claim_type")
    @Enumerated(EnumType.STRING)
    private ClaimType claimType;

    @Column(name = "claim_status")
    @Enumerated(EnumType.STRING)
    private ClaimStatus claimStatus;

    @Column(name = "fraud_status")
    @Enumerated(EnumType.STRING)
    private FraudStatus fraudStatus;

    @Column(name = "claim_amount")
    private BigDecimal claimAmount;

    @Column(name = "fraud_score")
    private BigDecimal fraudScore;

    @Column(name = "description")
    private String description;

    @Column(name = "incident_date",nullable = false)
    @NotNull(message = "Incident date is required")
    private Instant incidentDate;

    @Column(name = "incident_address")
    private String incidentAddress;
    @Column(name = "incident_city")
    private String incidentCity;
    @Column(name = "incident_state")
    private String incidentState;

    @Column(name = "decision_notes",columnDefinition = "TEXT")
    private String decisionNotes;

    @Column(name = "review_notes",columnDefinition = "TEXT")
    private String reviewNotes;

    @Column(name = "created_at",nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at",nullable = false)
    private Instant updatedAt;

    @Column(name = "is_deleted")
    private boolean isDeleted = false;

    @Column(name = "deleted_at")
    private Instant deletedAt;

    @PrePersist
    public void  prePersist(){
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    @PreUpdate
    public void preUpdate(){
        this.updatedAt = Instant.now();
    }

}
