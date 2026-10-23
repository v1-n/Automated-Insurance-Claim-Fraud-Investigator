# FraudGuard — System Design & Database Design (diagrams)

Render with any Markdown viewer that supports Mermaid (GitHub, VS Code + Markdown Preview Mermaid Support, Obsidian).
Broker variant: RabbitMQ. Column lists for existing tables are simplified; verify against the entities.

## 1. System architecture

```mermaid
flowchart TD
    App[Flutter / React App]

    subgraph Backend["Spring Boot (modular monolith)"]
        API[Claim / Document / Notification Controllers]
        DB[(MySQL)]
        Relay[Outbox Relay<br/>SKIP LOCKED + lease]
        AiC[AI Analysis Consumer<br/>concurrency 2, manual ack]
        NotC[Notification Planner Consumer]
        Del[Delivery Workers<br/>email / push]
    end

    subgraph Infra[External services]
        MQ{{RabbitMQ<br/>exchange: fraudguard.events}}
        AI[FastAPI AI Service]
        CL[(Cloudinary)]
        FCM[Firebase FCM]
        BR[Brevo Email]
    end

    App -- "1 POST /claims + upload docs" --> API
    App -- "2 POST /claims/id/submit" --> API
    API -- "3 TX: submitted_at + outbox CLAIM_SUBMITTED" --> DB
    DB -. "4 poll NEW rows" .-> Relay
    Relay -- "5 publish, wait confirm, mark PUBLISHED" --> MQ
    MQ -- "claim.submitted" --> NotC
    MQ -- "claim.analysis.requested" --> AiC
    AiC -- "6 create run (unique claim_id + version)" --> DB
    AiC -- "7 POST /analyze-claim + X-Internal-Key" --> AI
    AI -- "8 download files" --> CL
    AI -- "9 risk score, flags, pHashes" --> AiC
    AiC -- "10 TX: save results + outbox AI_ANALYSIS_READY, then ack" --> DB
    NotC -- "in-app row + delivery rows" --> DB
    DB -.-> Del
    Del --> FCM
    Del --> BR
    MQ -. "retry queue, then DLQ" .-> AiC
    AiC -. "retries exhausted: ai_status = UNSCORED" .-> DB
    App -- "GET /notifications, /ai-analysis" --> API
```

## 2. Claim submit to AI result (sequence)

```mermaid
sequenceDiagram
    autonumber
    participant C as Customer App
    participant S as Spring API
    participant D as MySQL
    participant R as Outbox Relay
    participant Q as RabbitMQ
    participant N as Notification Consumer
    participant A as AI Consumer
    participant F as FastAPI AI Service
    participant I as Investigator App

    C->>S: POST /claims/{id}/submit
    S->>D: TX: set submitted_at, insert outbox_event
    S-->>C: 200 submitted
    R->>D: poll NEW events (SKIP LOCKED)
    R->>Q: publish claim.submitted + claim.analysis.requested
    R->>D: mark PUBLISHED after confirm
    Q->>N: claim.submitted
    N->>D: notification + delivery rows (idempotent)
    Q->>A: claim.analysis.requested
    A->>D: create/lock claim_analysis_run
    A->>F: POST /api/v1/analyze-claim
    F-->>A: score, flags, pHashes
    A->>D: TX: save flags, claim ai fields, outbox AI_ANALYSIS_READY
    A->>Q: ack
    Note over D,I: AI_ANALYSIS_READY flows through the same pipeline
    I->>S: GET /claims/{id}/ai-analysis
    S-->>I: risk, flags (advisory only)
```

## 3. State machines

```mermaid
stateDiagram-v2
    direction LR
    [*] --> NEW
    NEW --> PROCESSING: relay leases row
    PROCESSING --> PUBLISHED: broker confirm
    PROCESSING --> NEW: failure, backoff + jitter
    PROCESSING --> NEW: lease expired
    NEW --> DEAD: attempts exhausted
    PUBLISHED --> [*]
    DEAD --> NEW: admin replay
```

```mermaid
stateDiagram-v2
    direction LR
    [*] --> QUEUED
    QUEUED --> RUNNING
    RUNNING --> DONE: result saved
    RUNNING --> QUEUED: retryable error
    RUNNING --> FAILED: permanent error / retries exhausted
    QUEUED --> SUPERSEDED: newer version queued
    FAILED --> [*]: claim.ai_status = UNSCORED
    DONE --> [*]
```

## 4. Database design (ER diagram)

```mermaid
erDiagram
    TENANTS ||--o{ USERS : has
    TENANTS ||--o{ POLICY_PLANS : offers
    TENANTS ||--o{ POLICIES : owns
    TENANTS ||--o{ CLAIMS : owns
    ROLES ||--o{ USERS : assigned
    USERS ||--o{ REFRESH_TOKENS : has
    USERS ||--o{ POLICIES : buys
    POLICY_PLANS ||--o{ POLICIES : template
    POLICIES ||--o{ CLAIMS : covers
    USERS ||--o{ CLAIMS : files
    USERS ||--o{ CLAIMS : investigates
    CLAIMS ||--o{ CLAIM_DOCUMENTS : has
    CLAIMS ||--o{ CLAIM_ANALYSIS_RUNS : analysed_by
    CLAIM_ANALYSIS_RUNS ||--o{ CLAIM_AI_FLAG : produces
    USERS ||--o{ NOTIFICATION : receives
    NOTIFICATION ||--o{ NOTIFICATION_DELIVERY : delivered_via
    USERS ||--o{ DEVICE_TOKEN : registers
    USERS ||--o{ NOTIFICATION_PREFERENCE : sets

    TENANTS {
        bigint tenant_id PK
        varchar tenant_code UK
        varchar name
        varchar status
    }
    ROLES {
        bigint role_id PK
        varchar role_code UK
    }
    USERS {
        bigint user_id PK
        bigint tenant_id FK
        bigint role_id FK
        varchar email UK
        varchar password_hash
        varchar status
        boolean is_deleted
    }
    REFRESH_TOKENS {
        bigint id PK
        bigint user_id FK
        varchar token_hash
        datetime expires_at
        boolean revoked
    }
    POLICY_PLANS {
        bigint plan_id PK
        bigint tenant_id FK
        varchar name
        varchar policy_type
        decimal max_idv
    }
    POLICIES {
        bigint policy_id PK
        bigint tenant_id FK
        bigint user_id FK
        bigint plan_id FK
        varchar policy_number UK
        varchar vehicle_number
        decimal insured_declared_value
        datetime policy_start_date
        datetime policy_end_date
        varchar policy_status
    }
    CLAIMS {
        bigint claim_id PK
        bigint tenant_id FK
        bigint user_id FK
        bigint assigned_investigator_id FK
        bigint policy_id FK
        varchar claim_number UK
        varchar claim_type
        varchar claim_status
        varchar fraud_status
        decimal claim_amount
        decimal fraud_score
        datetime incident_date
        varchar incident_city
        varchar incident_state
        datetime submitted_at
        varchar ai_status
        varchar ai_risk_level
        varchar ai_recommendation
        datetime ai_analyzed_at
        text review_notes
        text decision_notes
        boolean is_deleted
    }
    CLAIM_DOCUMENTS {
        bigint claim_doc_id PK
        bigint tenant_id FK
        bigint claim_id FK
        bigint uploaded_by FK
        varchar document_type
        text file_url
        varchar storage_provider
        varchar mime_type
        bigint file_size
        char phash
        boolean is_deleted
    }
    CLAIM_ANALYSIS_RUNS {
        bigint id PK
        bigint tenant_id FK
        bigint claim_id FK
        int version UK
        varchar status
        char input_hash
        int attempts
        int risk_score
        varchar risk_level
        varchar recommendation
        json raw_response
        datetime finished_at
    }
    CLAIM_AI_FLAG {
        bigint id PK
        bigint run_id FK
        bigint claim_id FK
        varchar flag_id
        varchar code
        varchar category
        varchar severity
        text explanation
        json benign_explanations
        json next_steps
        decimal confidence
    }
    OUTBOX_EVENT {
        bigint id PK
        bigint tenant_id
        varchar event_type
        varchar aggregate_type
        bigint aggregate_id
        json payload
        varchar status
        int attempts
        datetime next_attempt_at
        datetime locked_until
    }
    NOTIFICATION {
        bigint id PK
        bigint tenant_id
        bigint user_id FK
        varchar type
        varchar title
        varchar body
        bigint claim_id
        varchar dedupe_key UK
        datetime read_at
    }
    NOTIFICATION_DELIVERY {
        bigint id PK
        bigint notification_id FK
        varchar channel
        varchar status
        int attempts
        datetime next_attempt_at
        varchar idempotency_key UK
    }
    DEVICE_TOKEN {
        bigint id PK
        bigint user_id FK
        varchar token UK
        varchar platform
        datetime last_seen_at
    }
    NOTIFICATION_PREFERENCE {
        bigint user_id PK
        varchar type PK
        varchar channel PK
        boolean enabled
    }
```

## 5. Key indexes and constraints

| Table | Index / constraint | Purpose |
|---|---|---|
| `outbox_event` | `(status, next_attempt_at, id)` | relay polling |
| `notification` | `UNIQUE (dedupe_key)` | no duplicate notifications on re-run |
| `notification` | `(user_id, read_at, created_at)` | unread list and count |
| `notification_delivery` | `UNIQUE (idempotency_key)` | no duplicate email/push |
| `notification_delivery` | `(status, next_attempt_at)` | delivery polling |
| `claim_analysis_runs` | `UNIQUE (claim_id, version)` | idempotent AI runs |
| `claim_documents` | `(tenant_id, phash)` | cross-claim duplicate photo lookup |
| `claim_ai_flag` | `(claim_id)`, `(run_id)` | flag lookups |
| `device_token` | `UNIQUE (token)` | one row per device |

## 6. Rules

- Spring Boot is the source of truth. The AI service never reads this database.
- Only `outbox_event` is written inside business transactions. Everything else is derived by consumers.
- AI writes only `fraud_score`, `ai_*` columns and `claim_ai_flag`. It never changes `claim_status` or `fraud_status`.
- Every query is tenant-scoped (`tenant_id`).
- Push payloads carry ids only, never PII, amounts or verdicts.