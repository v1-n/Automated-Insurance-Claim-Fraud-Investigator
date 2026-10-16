package com.insurancefraud.repository;

import com.insurancefraud.entity.Tenant;
import com.insurancefraud.entity.User;
import com.insurancefraud.enums.RoleCode;
import com.insurancefraud.enums.UserStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepo extends JpaRepository<User, Long> {

    boolean existsByEmail(String email);

    Optional<User> findByEmail(String email);

    @Query("""
        SELECT u FROM User u
        JOIN FETCH u.role
        JOIN FETCH u.tenant
        WHERE u.email = :email
    """)
    Optional<User> findByEmailWithRoleAndTenant(
            @Param("email") String email
    );

    @Query("""
        SELECT u FROM User u
        JOIN FETCH u.role
        JOIN FETCH u.tenant
        WHERE u.userId = :userId
    """)
    Optional<User> findByIdWithRoleAndTenant(
            @Param("userId") Long userId
    );

    List<User> findByTenantAndRole_RoleCodeAndIsDeletedFalseAndStatus(Tenant tenant, RoleCode roleCode, UserStatus userStatus);
    Optional<User>
    findByTenantAndRole_RoleCodeAndIsDeletedFalseAndStatusAndUserId(
            Tenant tenant,
            RoleCode roleCode,
            UserStatus status,
            Long userId
    );

}