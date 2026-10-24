package com.insurancefraud.outbox.repository;

import com.insurancefraud.entity.OutboxEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;

@Repository
public interface OutboxEventRepo extends JpaRepository<OutboxEvent, Long> {

    // Fetches ready events using MySQL 8.0 SKIP LOCKED + lease expiry check
    @Query(value = """
    SELECT * FROM outbox_events
    WHERE status IN ('NEW', 'PROCESSING')
      AND next_attempt_at <= :now
      AND (locked_until IS NULL OR locked_until < :now)
    ORDER BY event_id
    LIMIT :batchSize
    FOR UPDATE SKIP LOCKED
""", nativeQuery = true)
    List<OutboxEvent> findPendingEventsForLease(@Param("now") Instant now,
                                                @Param("batchSize") int batchSize);
}