package com.insurancefraud.repository;

import com.insurancefraud.entity.Role;
import com.insurancefraud.enums.RoleCode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface RoleRepo extends JpaRepository<Role,Long> {
    Optional<Role> findByRoleCode(RoleCode roleCode);
}
