package com.insurancefraud.fraud.repository;

import com.insurancefraud.entity.ClaimEvidenceFlag;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ClaimEvidenceFlagRepo extends JpaRepository<ClaimEvidenceFlag, Long> {
    List<ClaimEvidenceFlag> findByClaim_ClaimId(Long claimId);
    void deleteByClaim_ClaimId(Long claimId);
}