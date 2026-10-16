package com.insurancefraud.policy.repository;

import com.insurancefraud.entity.PolicyPlan;
import com.insurancefraud.entity.Tenant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PolicyPlanRepo extends JpaRepository<PolicyPlan, Long> {

    List<PolicyPlan> findByTenantAndIsActiveTrue(Tenant tenant);

    List<PolicyPlan> findByTenant(Tenant tenant);
}
