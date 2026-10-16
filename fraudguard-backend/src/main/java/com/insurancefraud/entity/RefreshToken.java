package com.insurancefraud.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import java.time.Instant;


@Entity
@Getter
@Setter
@Table(name = "refresh_token")
public class RefreshToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private  Long id;

    @Column(name = "token", nullable = false)
    private String token;

    @Column(name = "created_at")
    private Instant createdAt = Instant.now();

    @Column(name = "expires_at")
    private Instant expiresAt;

    private boolean revoked =false;

    @ManyToOne
    @JoinColumn(name =  "user_id",referencedColumnName = "user_id")
    @OnDelete(action = OnDeleteAction.CASCADE)
    private  User user;
}
