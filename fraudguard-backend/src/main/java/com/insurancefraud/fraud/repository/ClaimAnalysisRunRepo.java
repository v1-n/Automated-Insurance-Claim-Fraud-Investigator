package com.insurancefraud.fraud.repository;

import com.insurancefraud.entity.ClaimAnalysisRun;
import com.insurancefraud.enums.AnalysisRunStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ClaimAnalysisRunRepo extends JpaRepository<ClaimAnalysisRun, Long> {

    boolean existsByClaim_ClaimIdAndRunVersion(Long claimId, Integer runVersion);

    boolean existsByOutboxEventId(Long outboxEventId);

    boolean existsByOutboxEventIdAndStatus(Long outboxEventId, AnalysisRunStatus status);

    Optional<ClaimAnalysisRun> findFirstByOutboxEventIdOrderByRunIdDesc(Long outboxEventId);

    @Query("SELECT COALESCE(MAX(r.runVersion), 0) FROM ClaimAnalysisRun r WHERE r.claim.claimId = :claimId")
    Integer findLatestRunVersion(@Param("claimId") Long claimId);

    Optional<ClaimAnalysisRun> findByClaim_ClaimIdAndRunVersion(Long claimId, Integer runVersion);

    List<ClaimAnalysisRun> findByClaim_ClaimIdOrderByRunVersionDesc(Long claimId);
}
