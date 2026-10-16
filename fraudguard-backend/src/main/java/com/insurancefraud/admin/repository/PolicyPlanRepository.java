package com.insurancefraud.admin.repository;

import com.insurancefraud.entity.PolicyPlan;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PolicyPlanRepository extends JpaRepository<PolicyPlan, Long> {
}
