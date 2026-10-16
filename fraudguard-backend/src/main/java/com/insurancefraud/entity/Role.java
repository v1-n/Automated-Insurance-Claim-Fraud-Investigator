package com.insurancefraud.entity;

import com.insurancefraud.enums.RoleCode;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Setter
@Getter
@Table(name = "roles")
public class Role{

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "role_id",nullable = false)
    private Long roleId;

    @Enumerated(EnumType.STRING)
    @Column(name = "role_code", nullable = false, unique = true)
    private RoleCode roleCode;

    @Column(name = "role_name", nullable = false)
    private String roleName;
}
