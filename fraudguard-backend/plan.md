# FraudGuard — Notification + AI-Service Integration Plan

Detailed design and build plan for (1) the notification pipeline and (2) the Spring Boot ↔ FastAPI AI-service connection.
Based on the repo at commit `e792d2b` (backend, AI service, Flutter, docs). Every "current state" statement below was checked in code.

---

## 0. Decisions in one page

| # | Decision | Why |
|---|---|---|
| D1 | **Modular monolith + one AI microservice.** Notifications and the AI client live inside the Spring Boot app. | Notifications must commit in the same transaction as the claim. Splitting them forces a broker and re-creates the dual-write problem. |
| D2 | **One shared transactional outbox** (`outbox_event`). Notifications and AI analysis are both consumers of it. | Build the reliability mechanism once. |
| D3 | **Outbox events are fast fan-out only.** Slow work (email, FCM, AI call) happens in separate worker pools driven by their own tables (`notification_delivery`, `ai_analysis_job`). | A 60-second AI call must never delay a "claim approved" push. |
| D4 | **AI is triggered by an explicit `POST /claims/{id}/submit`, not by claim creation.** | Today `createClaim` runs before any document is uploaded (documents come via `POST /claims/{id}/documents`). Analysing at creation would analyse nothing. |
| D5 | **AI is advisory.** AI results go in their own columns/tables. They never write `fraudStatus` (the investigator's verdict) or `claimStatus`. | Matches IRDAI-style human-in-the-loop positioning and fixes known issue #6. |
| D6 | **At-least-once delivery + idempotency keys.** | Exactly-once does not exist across network boundaries. |
| D7 | **DB-backed queue now, broker later** behind an `EventPublisher` interface. | Solo project, free-tier hosting. Kafka/RabbitMQ add operations cost with no benefit yet. |
| D8 | **Introduce Flyway** with this work. | You are adding ~8 tables, enums and indexes. `ddl-auto=update` cannot manage that safely. |

---

## 1. Current state (verified) and gaps

### Backend (`fraudguard-backend`)
- Spring Boot 4.0.6, Java 21. No `@EnableScheduling`, no outbox, no broker, no ShedLock, no Flyway, no events (grep empty).
- `ClaimServiceImpl.createClaim` (`@Transactional`): requires an ACTIVE policy, saves the claim twice (temp number, then real number), sets `claimStatus=PENDING`, `fraudStatus=PENDING_ANALYSIS`. Returns no documents because none exist yet.
- Documents: `POST /api/v1/claims/{claimId}/documents` (separate call, one file at a time). `ClaimDocument` has `documentType` (`ACCIDENT_PHOTO, FIR, VEHICLE_DOCUMENT, POLICY_DOCUMENT, MEDICAL_REPORT, REPAIR_ESTIMATE, INVOICE, OTHER`), `fileUrl`, `storageProvider`, soft delete. **No hash column.**
- `Claim` has `fraudScore` (never written), `incidentDate` (Instant), `incidentCity`, `incidentState`, `claimAmount`, `policy`. **No incident latitude/longitude.**
- `Policy` has `vehicleNumber`, `insuredDeclaredValue`, `policyStartDate`, `policyEndDate` — everything the AI `ground_truth` needs.
- `EmailServiceImpl`: Brevo over `java.net.http.HttpClient`, `@Async("emailTaskExecutor")` fire-and-forget. **No retry, no record of failure.** It also logs the verification link (a token) at INFO — remove that.
- `ai.fraud.service.url` defaults to `http://localhost:8000/api/v1/analyze-claim`. No Java code calls it.
- `storage.provider` defaults to `local`. Local file URLs are **not** downloadable by the AI service (it only allows `https://*cloudinary.com`).

### AI service (`fraudguard-ai-service`, verified, 23 tests pass)
- `POST /api/v1/analyze-claim` (also `/verify-document`, `/inspect-photo`), all behind `X-Internal-Key`; `/health` public.
- Missing `AI_INTERNAL_KEY` → **503**; wrong/absent key → 401.
- Request: `tenant_id, claim_id, claim_number, claim_amount, ground_truth{vehicle_number, policy_number, policy_start_date, policy_end_date, idv_amount, incident_date, incident_city, incident_state, incident_latitude?, incident_longitude?}, documents[{claim_doc_id, document_type, document_url}], photos[{claim_doc_id, photo_url, existing_hashes?}]`.
- Response: `risk_score (0-100), risk_level, recommendation (FAST_TRACK|REVIEW|INVESTIGATE), summary, flags[{flag_id, code, category, severity, source, explanation, benign_explanations, next_steps, confidence}], details{document_summaries, photo_hashes[{claim_doc_id, phash}]}`.
- Partial failures become flags (`*_DOWNLOAD_FAILED`, `*_EXTRACTION_FAILED`, `PHOTO_DOWNLOAD_FAILED`, all MEDIUM), so the call still returns 200.
- Stateless. Runs documents and photos concurrently (max 4). Can take 10–60+ s for scanned PDFs (Tesseract OCR at 300 dpi).

### Gaps this plan closes
1. No durable event mechanism → outbox (§4).
2. Notifications are a static Flutter screen; email is fire-and-forget → notification module (§5).
3. No point in the lifecycle where "all evidence is in" → submit endpoint (§3).
4. No AI client, job table, result storage, pHash storage → AI module (§6).
5. No way to see failures or replay → ops tooling (§9).

---

## 2. Target architecture

```
                         Flutter / React
                               │  JWT
                               ▼
┌──────────────────────── Spring Boot (modular monolith) ────────────────────────┐
│                                                                                │
│  claim module ── @Transactional ──► claims row                                 │
│       │                          └► outbox_event row   (same commit)           │
│                                                                                │
│  outbox module                                                                 │
│   OutboxPoller (lease, SKIP LOCKED) ──► EventRouter                            │
│                                          ├─► NotificationPlanner                │
│                                          │     └─► notification + deliveries    │
│                                          └─► AiJobPlanner                       │
│                                                └─► ai_analysis_job (QUEUED)     │
│                                                                                │
│  notification module                      ai module                            │
│   DeliveryWorker (pool A)                  AiJobWorker (pool B, low concurrency)│
│    ├─ EMAIL  → Brevo HTTP                   ├─ builds request from DB           │
│    └─ PUSH   → FCM                          ├─ AiServiceClient (RestClient)     │
│   in-app = the notification row itself      └─ persists result, emits           │
│                                                AI_ANALYSIS_READY (outbox) ──┐  │
│                                                                             │  │
│   ◄─────────────────────────────────────────────────────────────────────────┘  │
└──────────────┬──────────────────────────────────────────────┬─────────────────┘
               │ HTTPS + X-Internal-Key                        │ MySQL (Aiven)
               ▼                                               
     FastAPI AI service (stateless)  ── downloads ──►  Cloudinary (https only)
```

Rules of the architecture:
- **Spring Boot is the source of truth.** The AI service never reads the main DB.
- **Only the outbox is written inside business transactions.** Everything else is derived by workers.
- **Two lanes:** fast (notification) and slow (AI), each with its own table, pool and timeouts.
- **AI failure never blocks claim filing.** Claim stays usable with `ai_status = UNSCORED`.

---

## 3. Claim lifecycle change (the key design decision)

Today: `POST /claims` → `POST /claims/{id}/documents` (n times). Nothing marks "done".

Add:

```
POST /api/v1/claims                    → claim created (DRAFT-like: submitted_at = null)
POST /api/v1/claims/{id}/documents     → uploads
POST /api/v1/claims/{id}/submit        → validates, sets submitted_at, emits CLAIM_SUBMITTED
```

`submit` rules (service layer, one transaction):
1. Caller owns the claim and tenant matches.
2. Not already submitted → if it is, return 200 with current state (**idempotent**; double-tap must not double-notify).
3. At least one non-deleted document. (Recommended: at least one `ACCIDENT_PHOTO`.)
4. Incident date not in the future and within the policy period (fixes issue #7 on the backend side too).
5. Set `submitted_at = now`, insert `outbox_event(CLAIM_SUBMITTED)`.

Events and when they fire:

| Event | Emitted by | Same tx as |
|---|---|---|
| `CLAIM_SUBMITTED` | `ClaimService.submit` | `claims.submitted_at` update |
| `CLAIM_ASSIGNED` | `AdminClaimService.assign` | assignment update |
| `REVIEW_SUBMITTED` | `InvestigatorClaimService.review` | verdict save |
| `CLAIM_APPROVED` / `CLAIM_REJECTED` | `AdminClaimService.decide` | decision save |
| `AI_ANALYSIS_READY` / `AI_ANALYSIS_FAILED` | `AiJobWorker` | result save |
| `DOCUMENT_ADDED_AFTER_SUBMIT` | `ClaimDocumentService.upload` (if `submitted_at != null`) | document save |

Compatibility: keep the Flutter flow working during rollout. Phase 1 makes `submit` optional; phase 3 makes the app call it.

---

## 4. Shared outbox

### 4.1 Schema (Flyway `V2__outbox.sql`)

```sql
CREATE TABLE outbox_event (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  tenant_id       BIGINT       NOT NULL,
  event_type      VARCHAR(50)  NOT NULL,
  aggregate_type  VARCHAR(30)  NOT NULL,          -- CLAIM
  aggregate_id    BIGINT       NOT NULL,
  payload         JSON         NOT NULL,          -- ids only, no PII
  status          VARCHAR(12)  NOT NULL DEFAULT 'NEW',  -- NEW, PROCESSING, DONE, DEAD
  attempts        INT          NOT NULL DEFAULT 0,
  next_attempt_at DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  locked_until    DATETIME(3)  NULL,
  last_error      VARCHAR(500) NULL,
  created_at      DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  processed_at    DATETIME(3)  NULL,
  KEY idx_outbox_poll (status, next_attempt_at, id),
  KEY idx_outbox_aggregate (aggregate_type, aggregate_id)
);
```

### 4.2 Publisher abstraction

```java
public interface EventPublisher {
    void publish(long tenantId, String type, String aggregateType, long aggregateId, Map<String,Object> payload);
}

@Component
class OutboxEventPublisher implements EventPublisher {
    private final OutboxEventRepository repo;
    private final ObjectMapper mapper;

    @Override
    @Transactional(propagation = Propagation.MANDATORY)   // fails loudly if called outside a business tx
    public void publish(...) { repo.save(OutboxEvent.newEvent(...)); }
}
```

`MANDATORY` is deliberate: it makes it impossible to "publish" without a surrounding business transaction.

### 4.3 Poller with leases

```java
@Component
class OutboxPoller {
    @Scheduled(fixedDelayString = "${outbox.poll-ms:1000}")
    void tick() {
        List<OutboxEvent> batch = claimer.claim(20, Duration.ofSeconds(60));
        for (OutboxEvent e : batch) handle(e);
    }

    private void handle(OutboxEvent e) {
        try {
            router.route(e);                    // fast: inserts rows only
            outboxService.markDone(e.getId());
        } catch (Exception ex) {
            outboxService.markFailed(e.getId(), ex, MAX_ATTEMPTS);   // backoff or DEAD
        }
    }
}

@Component
class OutboxClaimer {
    @Transactional
    List<OutboxEvent> claim(int n, Duration lease) {
        List<OutboxEvent> rows = repo.lockNextBatch(n);        // native, SKIP LOCKED
        Instant until = Instant.now().plus(lease);
        rows.forEach(r -> r.lease(until));                     // status=PROCESSING, locked_until
        return rows;                                           // tx commits: lease persisted, row locks released
    }
}
```

```sql
-- OutboxEventRepository.lockNextBatch
SELECT * FROM outbox_event
WHERE (status = 'NEW' AND next_attempt_at <= NOW(3))
   OR (status = 'PROCESSING' AND locked_until < NOW(3))   -- crashed worker: lease expired
ORDER BY id
LIMIT :n
FOR UPDATE SKIP LOCKED
```

Retry policy: `delay = min(30s × 2^attempts, 1h) + random(0..10s)`; after 8 attempts → `DEAD`.

Run the poller on every instance. `SKIP LOCKED` + leases make multiple instances safe, so no ShedLock is needed for the poller. (ShedLock is still useful for housekeeping jobs, §9.)

### 4.4 Router

```java
@Component
class EventRouter {
    void route(OutboxEvent e) {
        notificationPlanner.plan(e);                       // always safe: idempotent inserts
        if (e.type().equals("CLAIM_SUBMITTED") || e.type().equals("DOCUMENT_ADDED_AFTER_SUBMIT"))
            aiJobPlanner.plan(e);
    }
}
```

Both planners must be **idempotent**: unique keys (§5.1, §6.1) make a re-run after a crash harmless.

---

## 5. Notification module

### 5.1 Schema (`V3__notifications.sql`)

```sql
CREATE TABLE notification (            -- the in-app inbox, source of truth
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  tenant_id   BIGINT NOT NULL,
  user_id     BIGINT NOT NULL,
  type        VARCHAR(50)  NOT NULL,
  title       VARCHAR(150) NOT NULL,
  body        VARCHAR(500) NOT NULL,
  claim_id    BIGINT NULL,
  dedupe_key  VARCHAR(120) NOT NULL,   -- "<outboxEventId>:<userId>"
  read_at     DATETIME(3) NULL,
  created_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_notification_dedupe (dedupe_key),
  KEY idx_notification_user (user_id, read_at, created_at)
);

CREATE TABLE notification_delivery (   -- one row per external channel
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  notification_id BIGINT NOT NULL,
  channel         VARCHAR(10) NOT NULL,                 -- EMAIL, PUSH
  status          VARCHAR(10) NOT NULL DEFAULT 'PENDING', -- PENDING, SENDING, SENT, FAILED, DEAD, SKIPPED
  attempts        INT NOT NULL DEFAULT 0,
  next_attempt_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  locked_until    DATETIME(3) NULL,
  last_error      VARCHAR(500) NULL,
  idempotency_key VARCHAR(140) NOT NULL,                -- "<notificationId>:<channel>"
  sent_at         DATETIME(3) NULL,
  UNIQUE KEY uq_delivery_idem (idempotency_key),
  KEY idx_delivery_poll (status, next_attempt_at)
);

CREATE TABLE device_token (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  token VARCHAR(255) NOT NULL,
  platform VARCHAR(10) NOT NULL,                        -- ANDROID, IOS, WEB
  last_seen_at DATETIME(3) NOT NULL,
  UNIQUE KEY uq_device_token (token),
  KEY idx_device_user (user_id)
);

CREATE TABLE notification_preference (
  user_id BIGINT NOT NULL, type VARCHAR(50) NOT NULL, channel VARCHAR(10) NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (user_id, type, channel)
);
```

### 5.2 Planner: event → recipients → channels

| Event | Recipients | In-app | Email | Push |
|---|---|---|---|---|
| `CLAIM_SUBMITTED` | claim owner | ✔ | ✔ (receipt) | – |
| `CLAIM_SUBMITTED` | tenant admins | ✔ | – | ✔ |
| `CLAIM_ASSIGNED` | investigator | ✔ | – | ✔ |
| `CLAIM_ASSIGNED` | claim owner | ✔ | – | ✔ |
| `REVIEW_SUBMITTED` | tenant admins | ✔ | – | ✔ |
| `CLAIM_APPROVED` / `CLAIM_REJECTED` | claim owner | ✔ | ✔ | ✔ |
| `AI_ANALYSIS_READY` | assigned investigator, else tenant admins | ✔ | – | ✔ (only if risk ≠ LOW) |
| `AI_ANALYSIS_FAILED` | tenant admins | ✔ | – | – |

```java
@Transactional
public void plan(OutboxEvent e) {
    for (Recipient r : recipientResolver.resolve(e)) {          // tenant-scoped queries
        String dedupe = e.getId() + ":" + r.userId();
        if (notificationRepo.existsByDedupeKey(dedupe)) continue;   // re-run safe
        Notification n = notificationRepo.save(template.render(e, r, dedupe));
        for (Channel c : rules.channelsFor(e.getType(), r.role())) {
            if (prefs.allows(r.userId(), e.getType(), c))
                deliveryRepo.save(Delivery.pending(n.getId(), c));   // unique idempotency_key
        }
    }
}
```

Tenant safety: `recipientResolver` must always filter by `event.tenantId` (issue #13 — add a test).

### 5.3 Delivery worker

Separate `@Scheduled` loop and pool, same lease pattern on `notification_delivery`.

```java
void deliver(Delivery d) {
    try {
        switch (d.getChannel()) {
            case EMAIL -> emailSender.send(d);          // Brevo HTTP, 10s timeout
            case PUSH  -> pushSender.send(d);           // FCM
        }
        d.markSent();
    } catch (RetryableDeliveryException ex) {           // 429, 5xx, timeout, IO
        d.scheduleRetry(ex, MAX_ATTEMPTS);              // backoff + jitter, then DEAD
    } catch (PermanentDeliveryException ex) {           // 400/401/403, invalid address
        d.markDead(ex);
    }
}
```

Classification matters: retrying a 400 forever is a bug.

Channel specifics:
- **EMAIL:** wrap the existing Brevo call. Replace `@Async` fire-and-forget with this worker. Keep `sendVerificationEmail` as is for auth flows (or route it through the same table later).
- **PUSH (FCM):** Firebase Admin SDK for Java, service-account JSON from env/secret. Send to all tokens of the user. Treat `UNREGISTERED`/`INVALID_ARGUMENT` for a token as permanent → delete that `device_token` row, not a retry. Push payload = `{type, claimId}` + generic title ("Claim update"). **No amounts, names or fraud verdicts in push payloads.**
- **IN-APP:** no delivery row. The `notification` row *is* the delivery.

### 5.4 API

```
GET    /api/v1/notifications?unreadOnly=&page=&size=     → paginated
GET    /api/v1/notifications/unread-count
PATCH  /api/v1/notifications/{id}/read
POST   /api/v1/notifications/read-all
POST   /api/v1/devices                                   {token, platform}   (upsert)
DELETE /api/v1/devices/{token}                           (on logout)
GET/PUT /api/v1/notification-preferences
```

All scoped by the authenticated user. Cursor or page-based; index `(user_id, read_at, created_at)` serves the unread query.

### 5.5 Client changes
- **Flutter:** replace the hardcoded `notifications_screen.dart` items with `NotificationProvider` (poll `unread-count` every 30–60 s while foregrounded, badge on bell). Rename or retire `RealtimeService` (it is a local stream, not server push). Phase 5: add `firebase_messaging`, register the token after login (`POST /devices`), delete it on logout, tap handler opens the claim by `claimId`.
- **React:** same endpoints in `NotificationPage.jsx`.

---

## 6. AI-service connection module

### 6.1 Schema (`V4__ai.sql`)

```sql
ALTER TABLE claims
  ADD COLUMN submitted_at        DATETIME(3) NULL,
  ADD COLUMN ai_status           VARCHAR(12) NOT NULL DEFAULT 'NOT_REQUESTED', -- NOT_REQUESTED, QUEUED, RUNNING, COMPLETED, UNSCORED
  ADD COLUMN ai_risk_level       VARCHAR(10) NULL,
  ADD COLUMN ai_recommendation   VARCHAR(12) NULL,
  ADD COLUMN ai_analyzed_at      DATETIME(3) NULL;
-- reuse claims.fraud_score for the 0-100 AI score

ALTER TABLE claim_documents
  ADD COLUMN phash CHAR(16) NULL,                     -- 64-bit perceptual hash, photos only
  ADD KEY idx_doc_phash (tenant_id, phash);

CREATE TABLE ai_analysis_job (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  tenant_id       BIGINT NOT NULL,
  claim_id        BIGINT NOT NULL,
  version         INT    NOT NULL,                    -- 1,2,3… per claim (re-analysis)
  status          VARCHAR(12) NOT NULL DEFAULT 'QUEUED',  -- QUEUED, RUNNING, DONE, FAILED, SUPERSEDED
  input_hash      CHAR(64) NOT NULL,                  -- sha256 of document ids+urls+ground truth
  attempts        INT NOT NULL DEFAULT 0,
  next_attempt_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  locked_until    DATETIME(3) NULL,
  last_error      VARCHAR(500) NULL,
  risk_score      INT NULL,
  risk_level      VARCHAR(10) NULL,
  recommendation  VARCHAR(12) NULL,
  summary         VARCHAR(1000) NULL,
  raw_response    JSON NULL,                          -- full AI JSON for audit/replay
  requested_by_event BIGINT NULL,
  created_at      DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  finished_at     DATETIME(3) NULL,
  UNIQUE KEY uq_job_claim_version (claim_id, version),
  KEY idx_job_poll (status, next_attempt_at)
);

CREATE TABLE claim_ai_flag (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  job_id BIGINT NOT NULL, claim_id BIGINT NOT NULL, tenant_id BIGINT NOT NULL,
  flag_id VARCHAR(40) NOT NULL, code VARCHAR(80) NOT NULL, category VARCHAR(30) NOT NULL,
  severity VARCHAR(8) NOT NULL, source VARCHAR(30) NOT NULL,
  explanation TEXT NOT NULL,
  benign_explanations JSON NULL, next_steps JSON NULL,
  confidence DECIMAL(3,2) NULL,
  KEY idx_flag_claim (claim_id), KEY idx_flag_job (job_id)
);
```

Why a job table and not just "call from the outbox handler": the outbox handler must stay fast (§D3). The job table also gives versions, audit (`raw_response`), per-job retries and a status the UI can show.

### 6.2 Planner (runs inside the outbox router)

```java
@Transactional
void plan(OutboxEvent e) {
    long claimId = e.getAggregateId();
    String inputHash = inputHasher.hash(claimId);                   // docs + urls + policy facts
    Optional<AiAnalysisJob> latest = jobRepo.findTopByClaimIdOrderByVersionDesc(claimId);
    if (latest.isPresent() && latest.get().getInputHash().equals(inputHash)
        && latest.get().getStatus() != FAILED) return;              // nothing new to analyse (idempotent)
    latest.filter(j -> j.getStatus() == QUEUED).ifPresent(AiAnalysisJob::supersede);  // coalesce bursts
    jobRepo.save(AiAnalysisJob.queued(tenantId, claimId, nextVersion, inputHash, e.getId()));
    claimRepo.updateAiStatus(claimId, QUEUED);
}
```

Upload bursts: if a user adds three documents after submit, three `DOCUMENT_ADDED_AFTER_SUBMIT` events arrive. Coalesce by setting `next_attempt_at = now + 2 min` on the QUEUED job and superseding earlier QUEUED jobs, so you run AI once, not three times.

### 6.3 Worker

Separate pool, **concurrency 2** (the AI service is CPU-bound on free-tier hardware).

```java
@Scheduled(fixedDelayString = "${ai.worker.poll-ms:2000}")
void tick() {
    jobClaimer.claim(2, Duration.ofSeconds(180))        // lease > client read timeout (120s)
              .forEach(this::run);
}

void run(AiAnalysisJob job) {
    try {
        AnalyzeClaimRequest req = requestBuilder.build(job);       // reads DB, §6.4
        AnalyzeClaimResponse res = aiClient.analyze(req);          // §6.5
        resultWriter.persist(job.getId(), res);                    // one tx, §6.6
    } catch (AiRetryableException ex) {
        jobService.scheduleRetry(job.getId(), ex, MAX_ATTEMPTS);   // 5 attempts, longer backoff
    } catch (AiPermanentException ex) {
        jobService.fail(job.getId(), ex);                          // → UNSCORED + AI_ANALYSIS_FAILED
    }
}
```

### 6.4 Building the request (Spring entities → AI contract)

| AI field | Source |
|---|---|
| `tenant_id` | `claim.tenant.tenantCode` |
| `claim_id`, `claim_number`, `claim_amount` | `claim` |
| `ground_truth.vehicle_number` | `claim.policy.vehicleNumber` |
| `ground_truth.policy_number/start/end` | `claim.policy` (Instant → ISO-8601 string) |
| `ground_truth.idv_amount` | `claim.policy.insuredDeclaredValue` |
| `ground_truth.incident_date/city/state` | `claim` |
| `incident_latitude/longitude` | **not stored today** → add nullable columns and capture in the Flutter claim form (device GPS, optional), or omit (AI skips the GPS check when absent) |
| `documents[]` | non-deleted docs where `documentType != ACCIDENT_PHOTO` |
| `photos[]` | non-deleted docs where `documentType == ACCIDENT_PHOTO` |
| `photos[].existing_hashes` | `SELECT DISTINCT phash FROM claim_documents WHERE tenant_id=? AND claim_id<>? AND phash IS NOT NULL` (cap 5 000 newest; tenant-scoped on purpose) |

Preconditions checked before calling (fail fast as permanent errors):
- every `fileUrl` is `https` and host ends with `cloudinary.com` (otherwise the AI service will only return `*_DOWNLOAD_FAILED` flags). **This means production must run `storage.provider=cloudinary`.** Local mode will always produce download-failed flags.
- If Cloudinary assets become private/signed, generate short-lived signed URLs in the builder.

Enum mapping: `DocumentType` values already match the AI service's `DocumentType`. Verify with a contract test (§11).

### 6.5 Client

```java
@Component
class AiServiceClient {
    private final RestClient rest;

    AiServiceClient(@Value("${ai.service.base-url}") String baseUrl,
                    @Value("${ai.service.internal-key}") String key) {
        var factory = new JdkClientHttpRequestFactory(
            HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build());
        factory.setReadTimeout(Duration.ofSeconds(120));
        this.rest = RestClient.builder().baseUrl(baseUrl).requestFactory(factory)
            .defaultHeader("X-Internal-Key", key).build();
    }

    AnalyzeClaimResponse analyze(AnalyzeClaimRequest req) {
        try {
            return rest.post().uri("/api/v1/analyze-claim").body(req)
                       .retrieve().body(AnalyzeClaimResponse.class);
        } catch (HttpStatusCodeException e) { throw classify(e); }
        catch (ResourceAccessException e)   { throw new AiRetryableException("timeout/connect", e); }
    }

    private RuntimeException classify(HttpStatusCodeException e) {
        int s = e.getStatusCode().value();
        if (s == 429 || s == 502 || s == 504)  return new AiRetryableException("HTTP " + s, e);
        if (s == 500 || s == 503)              return new AiRetryableException("HTTP " + s, e); // 503 = AI misconfigured; retry, alert after N
        return new AiPermanentException("HTTP " + s, e);                                        // 400/401/403/422
    }
}
```

Replace the single `ai.fraud.service.url` property with **base URL** + key: `AI_SERVICE_BASE_URL`, `AI_INTERNAL_KEY`. Fail startup in `prod` profile if the key is blank.

Retries live in the job worker (durable, visible in the DB). Do **not** also add in-process retries: stacking them multiplies attempts. A circuit breaker is optional; if you add Resilience4j, first verify its Spring Boot 4 support. A simple alternative is a pause flag: when 3 consecutive jobs fail retryably, delay all QUEUED jobs by 5 minutes.

Free-tier cold starts: Render free services sleep. The first call can take 30–60 s and time out. That is normal and is exactly what the durable retry covers. Optionally have `OutboxPoller` ping `/health` before the first call after idle time.

### 6.6 Persisting the result (single transaction)

```java
@Transactional
void persist(long jobId, AnalyzeClaimResponse res) {
    AiAnalysisJob job = jobRepo.findById(jobId).orElseThrow();
    if (job.getStatus() == SUPERSEDED) return;                       // newer job exists, discard
    job.complete(res.riskScore(), res.riskLevel(), res.recommendation(), res.summary(), json(res));
    flagRepo.saveAll(mapFlags(job, res.flags()));
    res.details().photoHashes().forEach(h -> docRepo.setPhash(h.claimDocId(), h.phash()));  // enables future duplicate checks
    claim.setFraudScore(BigDecimal.valueOf(res.riskScore()));
    claim.setAiRiskLevel(...); claim.setAiRecommendation(...); claim.setAiStatus(COMPLETED); claim.setAiAnalyzedAt(now);
    // fraudStatus and claimStatus are NOT touched: AI is advisory (D5)
    publisher.publish(tenantId, "AI_ANALYSIS_READY", "CLAIM", claimId, Map.of("jobId", jobId, "riskLevel", ...));
}
```

On permanent failure or exhausted retries: job → `FAILED`, claim `ai_status = UNSCORED`, publish `AI_ANALYSIS_FAILED`. The investigator still reviews the claim manually. Add an admin "Re-run analysis" endpoint that inserts a new job version.

### 6.7 Exposing results

```
GET  /api/v1/investigator/claims/{id}/ai-analysis     latest job + flags (investigator/admin only)
POST /api/v1/admin/claims/{id}/ai-analysis/rerun
```

- **Customers never see AI flags or scores.** (Customers seeing "SUSPECTED" signals is a legal and UX risk; this also answers known issue #23.)
- Response includes `risk_level`, `recommendation`, `summary`, each flag with `explanation`, `benignExplanations`, `nextSteps`, and a fixed disclaimer: *"Automated advisory. Not a fraud determination."*
- Flutter/React investigator screen: badge (LOW/MEDIUM/HIGH), expandable flags grouped by category, link each flag to its document.

---

## 7. End-to-end sequences

### 7.1 Happy path

```
Customer ─ POST /claims ───────────────► claims row                           (no events)
Customer ─ POST /claims/{id}/documents ► claim_documents rows (+ Cloudinary)
Customer ─ POST /claims/{id}/submit ───► tx: submitted_at + outbox CLAIM_SUBMITTED
Outbox poller (≤1 s) ─► router
    ├─ NotificationPlanner: owner (in-app+email), admins (in-app+push)
    └─ AiJobPlanner: ai_analysis_job v1 QUEUED, claims.ai_status=QUEUED
DeliveryWorker (≈seconds) ─► Brevo email, FCM push
AiJobWorker (≈2 s later) ─► build request ─► POST AI service ─► 10–60 s
    └─ tx: flags, score, phash, ai_status=COMPLETED, outbox AI_ANALYSIS_READY
Outbox ─► NotificationPlanner: investigator/admins in-app (+push if risk ≠ LOW)
Investigator opens claim ─► GET /ai-analysis ─► reviews ─► sets verdict (their own column)
```

### 7.2 Failure matrix

| Failure | Behaviour | Recovery |
|---|---|---|
| App crashes after claim save, before poller | Event row is in the DB | Poller picks it up on restart |
| Crash mid-poll | Lease expires (60 s) | Another poll re-claims; planners are idempotent |
| Duplicate event processing | `dedupe_key` / `idempotency_key` unique | Insert skipped |
| Brevo 5xx/timeout | Delivery `FAILED` + backoff | Retries to 8, then `DEAD` (visible in admin) |
| Brevo 400 (bad address) | Permanent | `DEAD`, no retry |
| FCM token invalid | Delete token | Other channels unaffected |
| AI service down / cold start | Retryable | Job retries (5 attempts, up to ~30 min), then `UNSCORED` |
| AI returns 401 | Config error, permanent | Alert admins; fix key; "Re-run" |
| AI returns partial flags | Normal 200 | Shown as MEDIUM `*_FAILED` flags |
| Docs added during analysis | New job v2 supersedes | v1 result discarded if v2 queued |
| Worker crash mid-AI call | Lease (180 s) expires | Job re-claimed; AI call is read-only and safe to repeat |
| DB failover | Transactions fail | Retry via normal poll loop |

---

## 8. Security

- **Service-to-service:** `X-Internal-Key` from env on both sides, HTTPS only, rotate by supporting two keys briefly. Keep the AI service reachable only by Spring if the platform allows private networking.
- **AI download allowlist** is already enforced (https + Cloudinary host, no redirects). Keep it.
- **Privacy:** the AI payload contains only IDs, vehicle number, policy dates/IDV, incident city/state, and document URLs. No customer name/phone/email.
- **Push/email content:** no verdicts, scores or amounts in push. Email to customers contains status only.
- **Tenant isolation:** every repository query in planners, workers and APIs filters by tenant; add integration tests that try cross-tenant access.
- **Secrets:** FCM service account, Brevo key, AI key, JWT secret come from env/secret store, never defaults (issue #3). Remove the INFO log of verification links.
- **Admin ops endpoints** (replay dead events) are ADMIN-only and audited.

---

## 9. Operations and observability

Metrics (Micrometer + Actuator, expose `health`, `metrics`; secure them):
- `outbox.pending`, `outbox.oldest_age_seconds`, `outbox.dead`
- `notification.delivery{channel,status}`, `notification.delivery.latency`
- `ai.job{status}`, `ai.call.duration`, `ai.call.failures{reason}`, `ai.unscored.count`

Alerts (even if just a daily log check at first): oldest outbox age > 5 min; DEAD count > 0; UNSCORED ratio > 20 %.

Logging: generate a `correlationId` at `submit`, store it in the outbox payload, put it in MDC in workers, and send it as `X-Correlation-Id` to the AI service (add it to the AI service's logs).

Admin tooling:
```
GET  /api/v1/admin/outbox?status=DEAD
POST /api/v1/admin/outbox/{id}/replay
GET  /api/v1/admin/notification-deliveries?status=DEAD
POST /api/v1/admin/notification-deliveries/{id}/retry
```

Housekeeping (nightly, ShedLock so only one instance runs): delete `DONE` outbox rows older than 14 days, `SENT` deliveries older than 30 days, read notifications older than 90 days, orphan device tokens not seen for 60 days.

Config (`application.properties`, all overridable by env):
```
outbox.poll-ms=1000
outbox.max-attempts=8
delivery.poll-ms=2000
ai.service.base-url=${AI_SERVICE_BASE_URL:http://localhost:8000}
ai.service.internal-key=${AI_INTERNAL_KEY:}
ai.service.read-timeout-seconds=120
ai.worker.concurrency=2
ai.worker.max-attempts=5
```

Deployment (Render): two services, the AI service from its Dockerfile (needs `AI_INTERNAL_KEY`), Spring gets `AI_SERVICE_BASE_URL` and the same key. Run Flyway on startup. Set `spring.jpa.hibernate.ddl-auto=validate`.

---

## 10. Package layout (backend)

```
com.insurancefraud
├── outbox/
│   ├── entity/OutboxEvent.java
│   ├── repository/OutboxEventRepository.java
│   ├── service/EventPublisher.java, OutboxEventPublisher.java, OutboxClaimer.java
│   ├── worker/OutboxPoller.java
│   └── router/EventRouter.java
├── notification/
│   ├── entity/{Notification,NotificationDelivery,DeviceToken,NotificationPreference}.java
│   ├── planner/{NotificationPlanner,RecipientResolver,ChannelRules,TemplateRenderer}.java
│   ├── worker/DeliveryWorker.java
│   ├── channel/{EmailSender,PushSender}.java
│   ├── controller/{NotificationController,DeviceController,PreferenceController}.java
│   └── dto/...
├── ai/
│   ├── entity/{AiAnalysisJob,ClaimAiFlag}.java
│   ├── planner/AiJobPlanner.java, InputHasher.java
│   ├── worker/AiJobWorker.java, AiJobClaimer.java
│   ├── client/{AiServiceClient,AiRetryableException,AiPermanentException}.java
│   ├── mapper/AnalyzeRequestBuilder.java
│   ├── service/AiResultWriter.java
│   ├── controller/{AiAnalysisController,AdminAiController}.java
│   └── dto/{AnalyzeClaimRequest,AnalyzeClaimResponse,...}.java   (mirror the FastAPI models)
└── common/config/{SchedulingConfig,WorkerExecutorConfig}.java
```

Flyway files: `src/main/resources/db/migration/V1__baseline.sql` (dump of the current schema), `V2__outbox.sql`, `V3__notifications.sql`, `V4__ai.sql`.

---

## 11. Testing plan

| Test | Tooling | Proves |
|---|---|---|
| Submit writes claim update **and** outbox row atomically; rollback removes both | Testcontainers MySQL | The reason for the outbox |
| Two pollers, 100 events → each handled exactly once | Testcontainers + threads | `SKIP LOCKED` + lease |
| Lease expiry re-claims a crashed row | Testcontainers, manipulate `locked_until` | Crash recovery |
| Planner re-run creates no duplicate notifications | Integration | Idempotency |
| Delivery classification (429 retry, 400 dead) | WireMock for Brevo/FCM fakes | Retry rules |
| AI client: 200, 401, 503, timeout | WireMock | Error classification |
| **Contract test:** serialize `AnalyzeClaimRequest`, post to the real FastAPI app (TestClient or container) | Pytest fixture JSON used by both sides | Field names/enums stay in sync |
| AI result persisted; `fraudStatus` unchanged | Integration | Advisory-only rule |
| Superseded job result is discarded | Integration | Re-analysis safety |
| Cross-tenant recipient / hash lookup returns nothing | Integration | Tenant isolation |
| Submit twice → one event | Integration | Idempotent submit |

Use Awaitility for async assertions (`await().atMost(10s)`), never `Thread.sleep`.

---

## 12. Phased build plan

| Phase | Scope | Done when | Est. (part-time) |
|---|---|---|---|
| **0** Prep | Add Flyway + baseline, `ddl-auto=validate`, `@EnableScheduling`, MDC/correlation filter, remove token logging, gitignore `images/` | App boots on a clean DB via migrations | 1–2 days |
| **1** Outbox core | `outbox_event`, publisher (MANDATORY), claimer, poller, router stub, metrics, replay endpoint | Event written in a tx is processed once with two instances; tests green | 3 days |
| **2** In-app notifications | `notification` table, planner for all events, `GET/PATCH` API, Flutter `NotificationProvider`, `submit` endpoint | Submitting a claim shows an in-app notification to owner and admins | 3–4 days |
| **3** Email channel | `notification_delivery`, worker, Brevo sender with classification, preferences, DEAD view | Killing Brevo for a minute loses no emails; they arrive after recovery | 3 days |
| **4** AI connection | `V4__ai.sql`, request builder, client, job planner/worker, result writer, investigator endpoint + screen, `AI_ANALYSIS_READY` notification | Submit → flags visible to investigator, claim never blocked when AI is stopped (`UNSCORED`) | 5–6 days |
| **5** Push (FCM) | device tokens, Firebase Admin sender, Flutter `firebase_messaging` | Push on assign/approve/AI-ready, invalid tokens auto-removed | 3–4 days |
| **6** Hardening | Cleanup jobs, alerts, load test (200 claims), docs update, README diagrams, optional incident lat/lon capture | Failure-matrix scenarios demonstrated with logs | 3 days |

Total ≈ 3.5–4 weeks part-time. Phases 1–4 deliver the core story; phase 5 is polish. Do not start phase 4 before phase 1 passes its concurrency test.

Order inside the repo (commits): `feat(outbox)`, `feat(notification-inapp)`, `feat(notification-email)`, `feat(ai-integration)`, `feat(push)`, `chore(ops)`.

---

## 13. Things to verify while building (not confirmed here)

- **Flyway on Spring Boot 4:** Boot 4 splits auto-configuration into per-technology starters. Check the current official name (likely `spring-boot-starter-flyway`) plus `flyway-mysql`.
- **RestClient timeouts API** on Framework 7 (`JdkClientHttpRequestFactory#setReadTimeout` shown above is the 6.x shape).
- **Resilience4j** compatibility with Boot 4 if you add it.
- **Aiven MySQL** supports `SKIP LOCKED` (MySQL 8.0+, yes) and your plan allows enough connections for 3 worker pools + web threads (set HikariCP `maximum-pool-size` consciously).
- **FCM Admin SDK** version and service-account handling on Render.

---

## 14. Resume / interview framing (accurate wording)

- "Designed and built a transactional-outbox event pipeline in Spring Boot/MySQL (leases, `SKIP LOCKED`, exponential backoff with jitter, DLQ and replay) driving idempotent in-app, email and FCM push notifications."
- "Integrated a Python FastAPI document/photo-forensics service via a durable job queue with versioned re-analysis, failure classification, and graceful degradation (`UNSCORED`) so AI outages never block claim filing."
- "Modular monolith with one separately deployed AI microservice, extractable to a broker-based notification service behind an `EventPublisher` interface."

Questions this prepares you for: dual-write problem; what happens on crash between send and mark-sent; how two instances avoid double processing; why AI is async and advisory; how you prevent duplicate analysis on upload bursts; cold-start handling; tenant isolation tests.

Avoid claiming "microservices", "Kafka", "exactly-once" or "real-time" unless built.

---

## 15. Open decisions for you

1. Require at least one `ACCIDENT_PHOTO` at submit? (Recommended yes.)
2. Should customers see a neutral "Under automated review" state while AI runs? (Recommended: show "Submitted", hide AI entirely.)
3. Capture incident GPS from the phone (privacy prompt) or only city/state?
4. Push for LOW-risk AI results: off by default (suggested), or on?
5. Keep MySQL queue until a real scaling reason appears (suggested), or move to RabbitMQ/Redis Streams for the learning value after phase 6?

---

## 16. Addendum — RabbitMQ variant (chosen design)

This addendum overrides D7 and §4.3–§6.3 where they conflict. Diagrams: `system-and-database-diagrams.md`.

**What changes**
- The outbox relay publishes to a RabbitMQ topic exchange `fraudguard.events` instead of calling planners directly. Rows go `NEW → PROCESSING → PUBLISHED` only after a **publisher confirm**; failures back off and end `DEAD`.
- Routing keys: `claim.submitted`, `claim.assigned`, `review.submitted`, `claim.decided`, `claim.analysis.requested`, `ai.analysis.ready`, `ai.analysis.failed`.
- Queues: `notification.planner.q` (binds `claim.*`, `review.*`, `ai.analysis.*`), `ai.analysis.q` (binds `claim.analysis.requested`). Each has a retry queue (TTL 30s → 2m → 10m via dead-letter back to the main queue) and a final `.dlq`.
- Consumers use **manual ack after the DB transaction commits**, `prefetch=1` for AI and `prefetch=10` for notifications, and `concurrency=2` for AI.
- `claim_analysis_runs` (formerly `ai_analysis_job`) is no longer the queue. It is the idempotency and audit record: `UNIQUE (claim_id, version)` makes a redelivered message a no-op.
- Messages carry ids only (`claimId`, `runId`, `eventId`). Consumers rebuild everything from MySQL.

**What stays the same**
- Submit endpoint, outbox written in the business transaction, idempotent planners (`dedupe_key`, `idempotency_key`), `notification_delivery` as the retry source for email/push, AI advisory-only, `UNSCORED` fallback, security, metrics, tests.

**Extra things to build and learn**
- Spring AMQP: `RabbitTemplate` with confirms (`publisher-confirm-type=correlated`), `@RabbitListener` with `acknowledge-mode=manual`, declarables for exchange/queues/DLX.
- Hosting: a managed free-tier RabbitMQ (check current limits) or a local Docker container in dev; add to `docker-compose.yml`.
- Tests: Testcontainers RabbitMQ; kill the consumer mid-message and assert redelivery produces exactly one run row.
- Duplicate publishes are expected (relay crashes after publish, before marking). Consumers must tolerate them.