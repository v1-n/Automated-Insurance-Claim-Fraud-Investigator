package com.insurancefraud.entity;

import com.insurancefraud.enums.Severity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Entity
@Getter
@Setter
@Table(name = "claim_evidence_flags")
public class ClaimEvidenceFlag {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "claim_id", nullable = false)
    private Claim claim;

    @Column(name = "flag_id", nullable = false)
    private String flagId;

    @Column(name = "code", nullable = false)
    private String code;

    @Column(name = "category")
    private String category;

    @Enumerated(EnumType.STRING)
    @Column(name = "severity", nullable = false)
    private Severity severity;

    @Column(name = "source")
    private String source;

    @Column(name = "explanation", columnDefinition = "TEXT")
    private String explanation;

    @Column(name = "confidence")
    private Double confidence;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();
}