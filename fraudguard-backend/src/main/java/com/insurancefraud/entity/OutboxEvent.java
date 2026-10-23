package com.insurancefraud.entity;

import com.insurancefraud.enums.ClaimType;
import com.insurancefraud.enums.EventType;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Table(name = "outbox_events")
@Entity
public class OutboxEvent {

    @Id
    @Column(name = "event_id",nullable = false)
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long eventId;


    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tenant_id",nullable = false)
    private Tenant tenant;

    @Column(name = "event_type")
    @Enumerated(EnumType.STRING)
    private EventType eventType;


}
