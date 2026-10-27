package com.insurancefraud.entity;

import com.insurancefraud.enums.AnalysisRunStatus;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Getter
@Setter
@NoArgsConstructor
@Table(
        name = "claim_analysis_runs",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_claim_analysis_run_version", columnNames = {"claim_id", "run_version"})
        }
)
public class ClaimAnalysisRun {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "run_id")
    private Long runId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tenant_id", nullable = false)
    private Tenant tenant;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "claim_id", nullable = false)
    private Claim claim;

    @Column(name = "run_version", nullable = false)
    private Integer runVersion;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 32)
    private AnalysisRunStatus status = AnalysisRunStatus.STARTED;

    @Column(name = "trigger_type", length = 64)
    private String triggerType;

    @Column(name = "outbox_event_id")
    private Long outboxEventId;

    @Column(name = "risk_score", precision = 5, scale = 2)
    private BigDecimal riskScore;

    @Column(name = "recommendation", length = 32)
    private String recommendation;

    @Column(name = "error_message", length = 1000)
    private String errorMessage;

    @Column(name = "started_at", nullable = false)
    private Instant startedAt = Instant.now();

    @Column(name = "completed_at")
    private Instant completedAt;
}
