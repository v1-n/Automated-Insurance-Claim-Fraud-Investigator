package com.insurancefraud.policy.controller;

import com.insurancefraud.policy.dto.AdminIssuePolicyDto;
import com.insurancefraud.policy.dto.PolicyPlanRequestDto;
import com.insurancefraud.policy.dto.PolicyPlanResponseDto;
import com.insurancefraud.policy.dto.PolicyResponseDto;
import com.insurancefraud.policy.service.AdminPolicyService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/admin/policies")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminPolicyController {

    private final AdminPolicyService adminPolicyService;

    @PostMapping("/plans")
    public ResponseEntity<PolicyPlanResponseDto> createPolicyPlan(@Valid @RequestBody PolicyPlanRequestDto requestDto) {
        PolicyPlanResponseDto createdPlan = adminPolicyService.createPolicyPlan(requestDto);
        return new ResponseEntity<>(createdPlan, HttpStatus.CREATED);
    }

    @GetMapping("/plans")
    public ResponseEntity<List<PolicyPlanResponseDto>> getAllPolicyPlans() {
        List<PolicyPlanResponseDto> plans = adminPolicyService.getAllPolicyPlans();
        return ResponseEntity.ok(plans);
    }

    @PostMapping("/issue")
    public ResponseEntity<PolicyResponseDto> issueDirectPolicy(@Valid @RequestBody AdminIssuePolicyDto requestDto) {
        PolicyResponseDto issuedPolicy = adminPolicyService.issueDirectPolicy(requestDto);
        return new ResponseEntity<>(issuedPolicy, HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<PolicyResponseDto>> getAllTenantPolicies() {
        List<PolicyResponseDto> policies = adminPolicyService.getAllTenantPolicies();
        return ResponseEntity.ok(policies);
    }
}
