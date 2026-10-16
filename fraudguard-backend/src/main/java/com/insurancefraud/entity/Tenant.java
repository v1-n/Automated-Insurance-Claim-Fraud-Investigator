package com.insurancefraud.entity;


import com.insurancefraud.enums.TenantStatus;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
@Table(name = "tenants")
public class Tenant {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "tenant_id",nullable = false)
    private  Long tenantId;

    @Column(name = "tenant_code",nullable = false,unique = true)
    private String tenantCode;

    @Column(nullable = false)
    private String name;

    @Enumerated(EnumType.STRING)
    private TenantStatus status;

}
