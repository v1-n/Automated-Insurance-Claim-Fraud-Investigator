package com.insurancefraud.policy.repository;

import com.insurancefraud.entity.Policy;
import com.insurancefraud.entity.PolicyPlan;
import com.insurancefraud.entity.Tenant;
import com.insurancefraud.entity.User;
import com.insurancefraud.enums.PolicyStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PolicyRepo extends JpaRepository<Policy, Long> {

    List<Policy> findByUser(User user);

    List<Policy> findByUserAndPolicyStatus(User user, PolicyStatus policyStatus);

    Optional<Policy> findFirstByUserAndPolicyStatusOrderByCreatedAtDesc(User user, PolicyStatus policyStatus);

    List<Policy> findByTenant(Tenant tenant);

    Optional<Policy> findByPolicyNumber(String policyNumber);

    boolean existsByUserAndPolicyPlanAndPolicyStatus(User user, PolicyPlan policyPlan, PolicyStatus policyStatus);
}
