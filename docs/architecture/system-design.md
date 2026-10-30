# FraudGuard System Architecture & Design 🏗️

This document details the multi-modal, event-driven architecture, service boundaries, and asynchronous data pipelines of the **FraudGuard** platform.

---

## 🏛️ 1. Multi-Tier Event-Driven Architecture Diagram

```mermaid
graph TD
    subgraph ClientLayer["Mobile Client Layer (Flutter 3.x / Dart)"]
        CustomerApp["Customer Portal\n- Buy Motor Policy\n- File Accident Claim\n- Real-time Claim Status"]
        InvestigatorApp["Investigator Portal\n- Workload Queue\n- Evidence Photos & OCR Inspection\n- Submit Fraud Finding"]
        AdminApp["Admin Dashboard\n- Manage Plans & Tenants\n- Workload Balances\n- Final Approval / Rejection"]
        FCMClient["Firebase Messaging Client\n- FCM Token Registration\n- Heads-Up Banner (Local Notifications)\n- Deep Link Navigation to Claim"]
    end

    subgraph GatewayLayer["API & Ingestion Layer (Spring Boot 3 / Java 21)"]
        APIGateway["Spring Security & RBAC Filter\n- Stateless JWT Validation\n- Multi-Tenant Isolation Filter"]
        ClaimController["Claim Controller\n- Claim Ingestion & State Machine\n- Document Storage Coordination"]
        NotificationController["Notification Controller\n- GET /api/v1/notifications\n- GET /unread-count\n- PATCH /{id}/read"]
        DeviceController["Device Controller\n- POST /api/v1/devices\n- Stores FCM Device Tokens"]
    end

    subgraph OutboxLayer["Transactional Outbox & Broker Layer"]
        OutboxTable[("MySQL outbox_events\n- Atomic with Claim Transaction\n- NEW, IN_FLIGHT, PUBLISHED, FAILED")]
        OutboxRelay["Outbox Relay Poller\n- Scheduled every 3s\n- RabbitMQ Publisher Confirms\n- Exponential Backoff Retries"]
        RabbitExchange{{"RabbitMQ Exchange\nfraudguard.events (Topic)"}}
        QueueAI["fraudguard.claim.analysis\n(claim.submitted)"]
        QueuePush["fraudguard.notify.push\n(claim.*, ai.*, review.*)"]
        QueueDLQ["fraudguard.claim.analysis.dlx\n(Dead Letter Queue)"]
    end

    subgraph ConsumerLayer["Asynchronous Worker & Consumer Layer"]
        AIConsumer["ClaimAnalysisConsumer\n- Consumes claim.submitted\n- Fetches Existing pHashes\n- Calls AI Service\n- Emits ai.analysis.ready Event"]
        PushConsumer["PushNotificationConsumer\n- Resolves Recipient User ID\n- Persists In-App Notification\n- Dispatches FCM v1 Push"]
        StuckSweeper["Stuck-Run Sweeper (@Scheduled)\n- Recovers timed-out analyses\n- Rerun guard & DLQ fallback"]
    end

    subgraph AILayer["AI Fraud Inspection Microservice (FastAPI / Python 3.12)"]
        InternalAuth["Internal Auth Guard\n- X-Internal-Key Check (Fail-Closed)"]
        AsyncEngine["Bounded Concurrency Engine\n- Semaphore(4) Parallel Download & OCR"]
        DocModule["Document Verification Engine\n- PyMuPDF + Tesseract OCR\n- 4-State Vehicle Registration Matcher\n- BNS vs IPC Legal Code Rule"]
        PhotoModule["Photo Forensics Engine\n- 64-bit Perceptual Hash (pHash)\n- EXIF Tampering / Photoshop Detector\n- Graduated Date Tolerance (IST)\n- Haversine GPS Distance Check"]
        ScoringModule["Risk Scoring & Flag Engine\n- 0-100 Score Aggregator\n- FAST_TRACK, REVIEW, INVESTIGATE"]
    end

    subgraph StorageLayer["Data & Cloud Infrastructure"]
        CloudinaryStorage["Cloudinary CDN\n- Secure Media Vault\n- PDFs, FIRs, Damage Photos"]
        Database[(Aiven Cloud MySQL 8.0\n- Policies, Claims, Users, Tenants\n- Notifications, Devices, pHashes)]
        FCMBackend["Firebase Cloud Messaging (FCM v1)\n- Google OAuth 2.0 Auth\n- Push Dispatch to Mobile"]
    end

    %% Client flows
    CustomerApp -->|HTTPS / REST| APIGateway
    InvestigatorApp -->|HTTPS / REST| APIGateway
    AdminApp -->|HTTPS / REST| APIGateway
    FCMClient -->|Register Token| DeviceController

    %% Gateway to services
    APIGateway --> ClaimController
    APIGateway --> NotificationController
    APIGateway --> DeviceController

    %% Outbox writes
    ClaimController -->|1. Commit Claim + OutboxEvent| Database
    Database -.-> OutboxTable
    OutboxTable -->|2. Poll NEW events| OutboxRelay
    OutboxRelay -->|3. Publish with Confirm| RabbitExchange

    %% RabbitMQ routing
    RabbitExchange -->|claim.submitted| QueueAI
    RabbitExchange -->|claim.*, ai.*, review.*| QueuePush
    QueueAI -->|3 Failed Attempts| QueueDLQ

    %% Consumers
    QueueAI --> AIConsumer
    QueuePush --> PushConsumer
    StuckSweeper -->|Inspect PENDING_ANALYSIS| Database

    %% AI Pipeline
    AIConsumer -->|POST /api/v1/analyze-claim\nX-Internal-Key| InternalAuth
    InternalAuth --> AsyncEngine
    AsyncEngine --> DocModule
    AsyncEngine --> PhotoModule
    AsyncEngine --> ScoringModule
    DocModule -->|Stream Download| CloudinaryStorage
    PhotoModule -->|Stream Download| CloudinaryStorage
    AIConsumer -->|Update Score & Flags\nEmit ai.analysis.ready| Database

    %% Push Pipeline
    PushConsumer -->|Save In-App Notification| Database
    PushConsumer -->|Query UserDevice| Database
    PushConsumer -->|Dispatch Push Payload| FCMBackend
    FCMBackend -->|Heads-Up Alert| FCMClient
```

---

## 🔄 2. End-to-End Claim Intake, AI Analysis & Notification Flow

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Policyholder (Mobile)
    participant API as Spring Boot API
    participant DB as MySQL (Claims, Outbox, Notifications)
    participant Relay as Outbox Relay
    participant MQ as RabbitMQ (fraudguard.events)
    participant AIWorker as ClaimAnalysisConsumer
    participant AIService as FastAPI AI Service
    participant PushWorker as PushNotificationConsumer
    participant FCM as Firebase Cloud Messaging
    actor Inv as Assigned Investigator (Mobile)

    %% Step 1: Claim Submission
    Customer->>API: POST /api/v1/claims (Incident details, Cloudinary photo URLs)
    critical Atomic DB Transaction
        API->>DB: Save Claim (status: PENDING_ANALYSIS, fraudScore: 0)
        API->>DB: Save OutboxEvent (type: claim.submitted, routingKey: claim.submitted)
    end
    API-->>Customer: 201 Created (Claim #18 queued)

    %% Step 2: Outbox Publishing
    loop Every 3 seconds
        Relay->>DB: Fetch un-published OutboxEvents (status: NEW)
        Relay->>MQ: Publish "claim.submitted" (mandatory=true, publisher confirms)
        MQ-->>Relay: Publisher ACK
        Relay->>DB: Mark OutboxEvent as PUBLISHED
    end

    %% Step 3: Parallel Fanout to AI and Push
    par AI Inspection
        MQ->>AIWorker: Deliver "claim.submitted"
        AIWorker->>DB: Query historical pHashes for duplicate check
        AIWorker->>AIService: POST /api/v1/analyze-claim (payload, X-Internal-Key)
        Note over AIService: Run OCR, 64-bit pHash, EXIF checks, GPS proximity
        AIService-->>AIWorker: AnalyzeClaimResponse (score: 72, flags: [TAMPERED_EXIF, NEAR_RC])
        critical Save Analysis & Queue Event
            AIWorker->>DB: Update Claim (fraudScore: 72, fraudStatus: SUSPICIOUS, aiStatus: COMPLETED)
            AIWorker->>DB: Save OutboxEvent (type: ai.analysis.ready)
        end
    and Immediate Submission Push
        MQ->>PushWorker: Deliver "claim.submitted"
        PushWorker->>DB: Save In-App Notification (title: "Claim Submitted", userId: customerId)
        PushWorker->>DB: Query UserDevice for customerId
        PushWorker->>FCM: Dispatch FCM Push message
        FCM-->>Customer: Heads-Up notification banner
    end

    %% Step 4: AI Analysis Complete Notification
    Relay->>MQ: Publish "ai.analysis.ready"
    MQ->>PushWorker: Deliver "ai.analysis.ready"
    PushWorker->>DB: Resolve Recipient (investigatorId)
    PushWorker->>DB: Save In-App Notification for Investigator
    PushWorker->>DB: Query UserDevice for investigatorId
    PushWorker->>FCM: Dispatch FCM Push message
    FCM-->>Inv: Heads-Up notification banner ("Claim #18 analysis ready")

    %% Step 5: Mobile In-App Navigation
    Inv->>Inv: Tap notification card on Notifications screen
    Note over Inv: App reads referenceId=18 & role=INVESTIGATOR<br/>Deep links directly to InvestigationDetailScreen(claimId: 18)
```

---

## 🛡️ 3. Reliability & Fault-Tolerance Mechanisms

### 3.1 Transactional Outbox Pattern
- Prevents the **dual-write problem** where a database transaction commits but the network message broker call fails.
- All domain events (`claim.submitted`, `claim.assigned`, `ai.analysis.ready`, `review.submitted`, `claim.approved`, `claim.rejected`) are persisted inside the local MySQL database transaction within the `outbox_events` table.
- A dedicated scheduled relay (`OutboxRelay`) polls un-published events, publishes them to RabbitMQ using **correlated publisher confirms**, and marks them `PUBLISHED` only after positive broker acknowledgment.

### 3.2 Dead-Letter Queue (DLQ) & 3-Strike Retry
- The RabbitMQ consumer is configured with **exponential backoff retry** (5s, 15s, 45s).
- If the AI microservice is temporarily down, the message retries 3 times.
- Upon 3 successive failures, the message is routed to `fraudguard.claim.analysis.dlx` (Dead Letter Queue) rather than being dropped or causing consumer thread lockup.

### 3.3 Stuck-Run Sweeper
- A background scheduler inspects claims lingering in `PENDING_ANALYSIS` beyond the configured timeout threshold.
- Automatically resets the state or requeues the analysis event, guaranteeing that no claim is permanently trapped in an unanalyzed state.

### 3.4 In-App Notification Idempotency & Deduplication
- `PushNotificationConsumer` verifies `existsByEventIdAndUser_UserId(eventId, recipientId)` before inserting into the `notifications` table.
- Prevents duplicate notification entries if RabbitMQ redelivers an unacknowledged message.

---

## 🔒 4. Production Security Architecture

1. **Stateless JWT with RBAC & Multi-Tenant Isolation**:
   - Enforced across endpoints via Spring Security and `@PreAuthorize`.
   - Automatic multi-tenant tenant ID filtering ensures strict company isolation (`TATA_AIG`, `MAHI`, etc.).
2. **Fail-Closed Microservice Authentication (`X-Internal-Key`)**:
   - The FastAPI AI microservice validates the secret using `hmac.compare_digest` to prevent timing attacks.
   - If `AI_INTERNAL_KEY` is not configured, the service responds with HTTP 503 instead of falling back to insecure defaults.
3. **Flexible Production Firebase Credential Discovery**:
   - Spring Boot checks:
     1. `FIREBASE_CREDENTIALS_JSON` environment variable (raw JSON string or Base64 encoded).
     2. `FIREBASE_CONFIG_PATH` file path (supporting Render Secret Files e.g., `/etc/secrets/firebase-adminsdk.json`).
     3. Local development classpath fallback (`ClassPathResource`).
   - Ensures zero private key exposure in git while supporting seamless container deployment.
4. **Hardened Asset Ingestion**:
   - Streamed downloads with a 25 MB byte cap to prevent memory exhaustion (OOM).
   - Domain allowlist (`res.cloudinary.com`, `cloudinary.com`) and open-redirect protection (`follow_redirects=False`) preventing SSRF.
