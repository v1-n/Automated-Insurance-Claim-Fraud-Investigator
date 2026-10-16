package com.insurancefraud.policy.controller;

import com.insurancefraud.policy.dto.CustomerSelectPolicyDto;
import com.insurancefraud.policy.dto.PolicyPlanResponseDto;
import com.insurancefraud.policy.dto.PolicyResponseDto;
import com.insurancefraud.policy.service.CustomerPolicyService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/policies")
@RequiredArgsConstructor
public class CustomerPolicyController {

    private final CustomerPolicyService customerPolicyService;

    @GetMapping("/plans")
    public ResponseEntity<List<PolicyPlanResponseDto>> getAvailablePlans() {
        List<PolicyPlanResponseDto> plans = customerPolicyService.getAvailablePlans();
        return ResponseEntity.ok(plans);
    }

    @PostMapping("/select")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<PolicyResponseDto> selectAndActivatePolicy(@Valid @RequestBody CustomerSelectPolicyDto requestDto) {
        PolicyResponseDto activePolicy = customerPolicyService.selectAndActivatePolicy(requestDto);
        return new ResponseEntity<>(activePolicy, HttpStatus.CREATED);
    }

    @GetMapping("/my-policies")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<List<PolicyResponseDto>> getMyPolicies() {
        List<PolicyResponseDto> myPolicies = customerPolicyService.getMyPolicies();
        return ResponseEntity.ok(myPolicies);
    }
}
