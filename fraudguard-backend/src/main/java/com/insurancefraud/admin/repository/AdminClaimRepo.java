package com.insurancefraud.admin.repository;

import com.insurancefraud.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AdminClaimRepo extends JpaRepository<User,Long> {
}
