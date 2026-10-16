package com.insurancefraud.auth.repository;

import com.insurancefraud.entity.RefreshToken;
import com.insurancefraud.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;


import java.util.List;
import java.util.Optional;

@Repository
public interface RefreshTokenRepo extends JpaRepository<RefreshToken,Long> {
    Optional<RefreshToken> findByToken(String refreshToken);
    List<RefreshToken> findByUser(User user);
}