# FraudGuard: System Design & Backend Architecture Interview Q&A Guide
> **Project**: Automated Insurance Claim Fraud Investigator (FraudGuard)  
> **Tech Stack**: Spring Boot 3 (Java 21), Python FastAPI, RabbitMQ, MySQL 8.0, Flutter  
> **Purpose**: A living document of architectural interview questions, system design trade-offs, and technical solutions implemented in this project.

---

## 📑 Table of Contents
1. [Distributed Systems & Architecture](#1-distributed-systems--architecture)
2. [Message Queues & RabbitMQ Internals](#2-message-queues--rabbitmq-internals)
3. [Transactional Outbox Pattern & Idempotency](#3-transactional-outbox-pattern--idempotency)
4. [AI Microservice Integration & Security](#4-ai-microservice-integration--security)
5. [Spring Boot & Concurrency Pitfalls](#5-spring-boot--concurrency-pitfalls)
6. [DevOps, Git & Deployment Strategies](#6-devops-git--deployment-strategies)

---

## 1. Distributed Systems & Architecture

### Q1: Why did you choose RabbitMQ over Apache Kafka for FraudGuard?
* **Interviewer Angle**: Testing your ability to evaluate tools based on workload characteristics rather than hype.
* **Elevator Pitch**:
  > *"We chose RabbitMQ because our workload consists of **discrete, variable-duration background tasks** (OCR, photo forensics, pHash calculations) taking 2–5 seconds per job, rather than high-velocity append-only event streams. RabbitMQ's competing-consumers model with `prefetch=1` distributes work dynamically across workers, whereas Kafka's partition-based model would lead to head-of-line blocking if one consumer is stuck on a heavy 50-page PDF."*
* **Deep Technical Points**:
  - **Head-of-Line Blocking**: In Kafka, an entire partition is blocked if a single message takes 10s to process. In RabbitMQ, idle workers pull the next message instantly.
  - **Queue Mechanics**: RabbitMQ is a smart-broker/dumb-consumer task queue with native per-message acknowledgment, Dead Letter Exchanges (DLX), and retries.
  - **Operational Footprint**: RabbitMQ requires ~100MB RAM vs. Kafka's multi-broker JVM and cluster coordination (KRaft/ZooKeeper) overhead.

---

### Q2: What is the "Dual-Write Problem" and how did you prevent it?
* **Interviewer Angle**: Testing consistency and data integrity in microservice/messaging architectures.
* **Elevator Pitch**:
  > *"The dual-write problem occurs when an application updates a database and publishes an event to a message broker sequentially. If the database commits but the network to the broker fails (or the server crashes), the message is lost forever, leading to data inconsistency. In FraudGuard, we prevented this using the **Transactional Outbox Pattern**."*
* **How We Solved It in FraudGuard**:
  - Inside a single `@Transactional` database commit, we update `claims` to `PENDING_ANALYSIS` **and** write a record to `outbox_events`.
  - Either both succeed or both rollback.
  - A separate background relay worker (`OutboxRelay`) polls the outbox table and publishes events to RabbitMQ reliably.

---

## 2. Message Queues & RabbitMQ Internals

### Q3: How do multiple consumers work on the same queue without conflict?
* **Interviewer Angle**: Understanding concurrency, atomicity, and task distribution in message brokers.
* **Elevator Pitch**:
  > *"We use the **Competing Consumers Pattern**. RabbitMQ delivers each message to strictly ONE worker. When a worker pulls a message, RabbitMQ transitions it to an `Unacked` state. Only when the worker completes processing and returns `channel.basicAck()` does RabbitMQ delete the message. If the worker crashes, the unacked message is automatically requeued for another worker."*
* **Key FraudGuard Settings**:
  - `concurrency = "2"`: Restricts active worker threads to 2 per node, preventing CPU spikes and Out-Of-Memory (OOM) errors during heavy Tesseract OCR tasks.
  - `prefetch = 1`: Enforces "Fair Dispatch"—RabbitMQ only gives a worker a new task after it has finished and acknowledged its current task.

---

### Q4: When do you use multiple consumers on 1 queue vs multiple queues on 1 exchange?
* **Interviewer Angle**: Understanding Work Queues (Load Balancing) vs Pub/Sub (Broadcasting).
* **Elevator Pitch**:
  > *"We use **both** in FraudGuard. For the same task (AI Fraud Analysis), multiple workers listen to the **same queue** to share the load. For different business tasks (AI Analysis vs. Sending Email/Push Notifications), we bind **separate queues** to the same `TopicExchange`. When a claim is submitted, RabbitMQ clones the event to both queues so that slow OCR tasks never delay user notification delivery."*

---

### Q5: What is a Dead Letter Queue (DLQ) and why is it essential?
* **Interviewer Angle**: Error handling, resilience, and preventing poison-pill messages.
* **Elevator Pitch**:
  > *"A Dead Letter Queue holds messages that cannot be processed successfully after maximum retry attempts. Without a DLQ, a corrupted or unreadable document would cause an infinite retry loop, choking the queue and crashing workers. In FraudGuard, unparseable files are NACKed and routed via `x-dead-letter-exchange` to `claim.analysis.dlq` for manual investigation."*

---

## 3. Transactional Outbox Pattern & Idempotency

### Q6: What is `SELECT ... FOR UPDATE SKIP LOCKED` and why is it used in the Outbox Relay?
* **Interviewer Angle**: Database concurrency, row locking, and multi-instance scalability.
* **Elevator Pitch**:
  > *"In a multi-node deployment with multiple backend instances running the Outbox poller, standard queries would cause race conditions or row-lock deadlocks. `SKIP LOCKED` (available in MySQL 8.0+) instructs the database to lock and return unlocked rows while skipping rows currently locked by other transactions. This allows multiple Outbox Relay instances to poll concurrently without overlapping or blocking each other."*

---

### Q7: What is an "Idempotent Consumer" and how did you implement it?
* **Interviewer Angle**: Handling at-least-once delivery duplicates in distributed messaging.
* **Elevator Pitch**:
  > *"Because the Outbox pattern guarantees **at-least-once delivery**, network failures or delayed ACKs can cause the same message to be redelivered. An idempotent consumer ensures that processing a duplicate message produces no side-effects and runs zero duplicate work."*
* **Implementation in FraudGuard**:
  1. **Idempotency Key Check**: Every Outbox event carries a unique `event_id` (UUID). The consumer checks `claimAnalysisRunRepo.existsByEventId(eventId)`. If it already exists, the consumer immediately calls `basicAck()` and discards the message.
  2. **Domain State Guard**: If `claim.getFraudStatus() != PENDING_ANALYSIS`, the consumer recognizes the claim has already been evaluated and skips re-execution.

---

## 4. AI Microservice Integration & Security

### Q8: How did you design the boundary between the Spring Boot backend and the Python AI microservice?
* **Interviewer Angle**: Microservice architecture, separation of concerns, and security.
* **Elevator Pitch**:
  > *"We designed the Python FastAPI service as a **stateless computation worker** that never connects directly to the MySQL database. Spring Boot remains the single source of truth. Spring aggregates the ground truth facts (policy details, vehicle registration, claim amounts, document URLs) and passes them via an HTTPS REST payload. The AI service performs OCR, EXIF forensics, and perceptual hash matching, returning structured JSON flags and a risk score."*
* **Security & Reliability**:
  - **Fail-Closed Authentication**: Internal communication uses a shared secret header (`X-Internal-Key`) validated using timing-attack-safe `hmac.compare_digest`. If the key is unset in production, requests return HTTP 503.
  - **Bounded Concurrency**: Python uses an `asyncio.Semaphore(4)` to prevent memory exhaustion when processing concurrent multi-page PDFs.

---

## 5. Spring Boot & Concurrency Pitfalls

### Q9: Why did `currentUserService.getCurrentActiveUser()` fail when called asynchronously, and how did you resolve it?
* **Interviewer Angle**: Understanding ThreadLocal variables and Spring Security architecture.
* **Elevator Pitch**:
  > *"Spring Security stores authentication context in `SecurityContextHolder`, which uses `ThreadLocal` storage tied to the incoming HTTP servlet thread. When executing code asynchronously via `@Async` or inside a `@RabbitListener`, execution runs on a background worker thread where `SecurityContextHolder` is empty. We resolved this by refactoring the service to pass IDs (`claimId`) explicitly and fetching the entity directly from the repository, removing dependency on the HTTP session context."*

---

### Q10: Why did a test endpoint return HTTP 403 Forbidden when mapped with `@Controller` instead of `@RestController`?
* **Interviewer Angle**: Spring MVC dispatching and error handling mechanics.
* **Elevator Pitch**:
  > *"A class annotated with `@Controller` interprets a returned `String` as the name of a view template (JSP/Thymeleaf). When the view resolution fails, Spring Boot internally forwards the request to `/error`. If `/error` is not explicitly permitted in `WebSecurityConfig`, Spring Security intercepts the internal forward and returns HTTP 403 Forbidden. Changing to `@RestController` (which includes `@ResponseBody`) writes the string directly to the HTTP response, and permitting `/error` prevents masked security errors."*

---

### Q11: Why are `claimStatus` and `fraudStatus` separated into two different enums?
* **Interviewer Angle**: Domain-Driven Design (DDD) and lifecycle separation.
* **Elevator Pitch**:
  > *"They represent two distinct lifecycles with different stakeholders. `ClaimStatus` represents the customer and claims adjuster lifecycle (`PENDING`, `UNDER_REVIEW`, `APPROVED`, `REJECTED`, `CLOSED`). `FraudStatus` represents the automated AI risk assessment state (`PENDING_ANALYSIS`, `CLEAR`, `SUSPECTED`, `CONFIRMED`). Decoupling them allows a claim to be administratively `PENDING` while the AI assessment has already marked it `CLEAR` for fast-track auto-approval."*

---

## 6. DevOps, Git & Deployment Strategies

### Q12: How do you prevent breaking a live production deployment while developing experimental features?
* **Interviewer Angle**: Release engineering, branching models, and CI/CD pipelines.
* **Elevator Pitch**:
  > *"Cloud PaaS platforms like Render auto-deploy on every push to the default branch (`main`). To develop RabbitMQ and AI integrations safely, we maintain a dedicated `dev` branch. All daily development, experiments, and unfinished integrations are pushed to `origin/dev`. Render continues serving the stable production build from `main`. Only when features pass automated integration tests and code review do we merge `dev` into `main`."*

---

### Q13: What columns are required in an Outbox Table and why?
* **Interviewer Angle**: Understanding the Transactional Outbox Pattern mechanics and multi-instance concurrency.
* **Elevator Pitch**:
  > *"An outbox table requires: `event_id` (UUID as idempotency key), `aggregate_type` & `aggregate_id` (entity identification), `event_type` (business event), `routing_key` (broker routing), `payload` (JSON state), `status` (`NEW`, `PROCESSING`, `PUBLISHED`, `FAILED`), `attempts` & `next_attempt_at` (exponential backoff retry scheduling), and `locked_until` (lease mechanism for multi-instance pollers)."*

---

### Q14: Why should the Outbox event be emitted on `claim.submit()` rather than `claim.create()` in a document-heavy workflow?
* **Interviewer Angle**: Practical distributed workflow design and event timing.
* **Elevator Pitch**:
  > *"In insurance claim applications, claim creation and document/photo uploading occur in separate steps. If `CLAIM_SUBMITTED` is published immediately on `createClaim()`, the Outbox Relay worker consumes the message while the user is still uploading photos in Flutter. The AI service would evaluate 0 photos and 0 documents, generating inaccurate false-positive fraud flags. Emitting the outbox event in `submitClaim()` guarantees that all files are committed to MySQL before AI forensics begins."*

---

### Q15: What causes 'The Java feature Flexible Constructor Bodies is only available with source level 25' in Spring Boot?
* **Interviewer Angle**: Deep Java language compilation mechanics, Lombok, and bytecode generation.
* **Elevator Pitch**:
  > *"In Java 21, statements before `super()` are not allowed (a preview feature in Java 22/25 via JEP 447). When Lombok's `@RequiredArgsConstructor` is placed on a class extending a concrete framework class (such as Spring Security's `OncePerRequestFilter`), the IDE compiler (ECJ) can misinterpret the generated bytecode as using 'Flexible Constructor Bodies'. The fix is to write an explicit constructor calling `super();`, bypassing Lombok's bytecode generator for subclasses."*

---

### Q16: What causes an Android ANR with 'reacting to signal 3' and 'Input dispatching timed out' in a Flutter mobile app?
* **Interviewer Angle**: Mobile OS architecture, Android runtime (ART), thread management, and resilient network design.
* **Elevator Pitch**:
  > *"On Android, the OS watchdog (`ActivityManagerService` / `InputDispatcher`) monitors the main UI thread. If user interactions (such as taps or key events) are not processed within **5,000 milliseconds**, Android flags an **ANR (Application Not Responding)**.*
  > *To capture diagnostics, Android sends **Signal 3 (`SIGQUIT`)** to the process. The ART runtime's `Signal Catcher` thread intercepts Signal 3, dumps the thread stack traces to `/data/anr/traces.txt` (or system `tombstoned`), and displays the system dialog: **'App isn't responding: Wait or Close'**.*
  > *In Flutter applications, common triggers include:*
  > *1. **Missing HTTP Timeouts**: When Dart's `http.Client` executes network requests without explicit `.timeout()`, a stalled socket, dropped ADB reverse bridge, or half-open TCP connection can hang indefinitely, locking user flows or state providers.*
  > *2. **Synchronous Main Thread Blocking**: Blocking operations or heavy computations executed on the platform main thread rather than in background workers (`compute()` / isolates).*
  > *3. **Autofill & System IPC Contention**: When forms or text fields are mounted, Android invokes Autofill services (`googlequicksearchbox` / Gboard). If the UI thread is simultaneously stalled on network state updates, input dispatching exceeds the 5-second deadline.*
  > *The fix is to enforce strict request timeouts (`.timeout(Duration(seconds: 12))`), avoid synchronous UI isolate blocking, handle 401/403 authorization rejections gracefully, and offload heavy parsing to background threads."*

### Q17: Why should long-running external HTTP/AI calls never run inside a `@Transactional` boundary in Spring Boot?
* **Interviewer Angle**: Database connection pool management, thread starvation, HikariCP saturation, and transactional boundaries.
* **Elevator Pitch**:
  > *"When a Spring method is marked with `@Transactional`, Spring's `TransactionInterceptor` immediately borrows a physical database connection from the connection pool (HikariCP) before the method body begins. If that method executes a long-running external network call (such as a 30-to-90 second computer-vision inference call to a Python FastAPI service), that physical JDBC connection remains held and idle for the entire duration of the HTTP wait.*
  > *In production, if 10 concurrent claim analyses arrive, all 10 HikariCP pool connections become exhausted waiting on external I/O. As a consequence, completely unrelated REST APIs (like user login or policy lookups) freeze and throw `ConnectionTimeoutException: Connection is not available, request timed out after 30000ms`.*
  > *The architectural fix is to break the workflow into three explicit phases:*
  > *1. **Read Phase**: Query necessary metadata.*
  > *2. **Non-Transactional Remote Call**: Execute the external REST/HTTP call completely outside `@Transactional`.*
  > *3. **Write Phase**: Persist the response inside a short, dedicated `@Transactional` helper method (holding the DB connection for only a few milliseconds)."*

---

### Q18: What is the 'Double-Encoding Serialization Trap' when publishing Outbox Events through RabbitTemplate?
* **Interviewer Angle**: Message serialization mechanics, Jackson `MessageConverter`, and API contract boundaries.
* **Elevator Pitch**:
  > *"When using the Transactional Outbox pattern, events are usually stored in MySQL as a raw JSON string column (`payload TEXT`). When the Outbox Relay reads that row, the payload in Java is of type `java.lang.String` (`"{\"claimId\": 1}"`).*
  > *If you pass that String directly into `rabbitTemplate.convertAndSend(exchange, routingKey, event.getPayload())` while configured with `Jackson2JsonMessageConverter`, Jackson evaluates the parameter type. Because it is a `String`, Jackson serializes it as a **JSON string literal**—escaping inner quotes and wrapping the payload in extra quotes: `"\"{\\\"claimId\\\": 1}\""`.*
  > *Downstream consumers (such as Python FastAPI, Go, or other microservices) fail deserialization or have to perform redundant double-decoding.*
  > *The fix is to either parse the stored payload string into a `JsonNode` via `objectMapper.readTree(event.getPayload())` before publishing, or send a strongly-typed Event Envelope object so the message converter serializes a native JSON object."*

---

### Q19: How do you prevent a 'Thundering Herd / Infinite Retry Loop' when a downstream consumer service is down in RabbitMQ?
* **Interviewer Angle**: Distributed systems resilience, poison pills, consumer backoff, and Dead Letter Exchanges (DLX).
* **Elevator Pitch**:
  > *"In Spring AMQP, the default behavior of `@RabbitListener` upon catching an uncaught exception is to reject and immediately requeue the message at the head of the queue. If downstream dependencies (like an AI microservice or payment gateway) suffer an outage, the message is continuously consumed, rejected, and requeued thousands of times per minute. This saturates the CPU, floods database connections, and pollutes logs.*
  > *To build a production-grade resilient consumer:*
  > *1. **Bounded Consumer Retries with Exponential Backoff**: Configure `spring.rabbitmq.listener.simple.retry.enabled=true` with a maximum limit (e.g., 3 attempts), an initial interval (e.g., 5s), and a backoff multiplier (e.g., 3x).*
  > *2. **Reject on Exhaustion**: Set `spring.rabbitmq.listener.simple.default-requeue-rejected=false` so exhausted messages are rejected rather than requeued indefinitely.*
  > *3. **Dead Letter Exchange (DLX) & Dead Letter Queue (DLQ)**: Configure the main queue with `x-dead-letter-exchange` pointing to a DLX (e.g., `fraudguard.dlx`) and `x-dead-letter-routing-key` pointing to a DLQ (`fraudguard.claim.analysis.dlq`).*
  > *Unprocessable messages are safely routed to the DLQ where SREs or automated replay jobs can inspect and reprocess them once the downstream service is healthy."*

---

### Q20: What is the 'Self-Collision Bug' in Cross-Claim Perceptual Hashing (pHash) and how is it resolved?
* **Interviewer Angle**: Deduplication algorithms, forensic image hashing, and state consistency across retry boundaries.
* **Elevator Pitch**:
  > *"To detect fraudulent claims reusing old accident photographs, FraudGuard computes 64-bit Perceptual Hashes (pHash) on uploaded accident images and queries historical hashes from the database for Hamming distance comparison (< 10).*
  > *A critical bug emerges if the repository query retrieves **all** historical hashes for a tenant without excluding the current claim: `SELECT d.phash FROM ClaimDocument d WHERE d.tenant.tenantId = :tenantId`.*
  > *When a claim is analyzed, its photo hashes are persisted. If the consumer fails midway or triggers a retry/re-analysis, the query now loads the claim's own photos as 'historical' photos. The AI service computes the distance against itself (Hamming distance = 0) and falsely flags the legitimate claim with `DUPLICATE_PHOTO_EXTERNAL`.*
  > *The fix is to enforce claim exclusion at the query layer: `... AND d.claim.claimId != :claimId`, guaranteeing that photos are only checked against **other** distinct historical claims."*

---

### Q21: How do you design an Idempotent Claim Submission endpoint with State Machine Guards?
* **Interviewer Angle**: State machine integrity, idempotent API design, race condition prevention, and defense in depth.
* **Elevator Pitch**:
  > *"In a multi-step claim workflow (1. Create Claim → 2. Upload Supporting Documents → 3. Finalize & Submit), the submit endpoint (`POST /claims/{id}/submit`) must be strictly guarded against abuse and network retries.*
  > *Without proper guards, two critical vulnerabilities occur:*
  > *1. **State Overwrite / Verdict Wipe**: A customer could invoke `/submit` on an already `APPROVED` or `UNDER_INVESTIGATION` claim, erroneously resetting its status to `PENDING` and wiping the investigator's decision.*
  > *2. **Ghost Claims**: Submitting before documents are uploaded dispatches an empty claim to the AI forensics pipeline.*
  > *The solution enforces four defensive checks in a single `@Transactional` method:*
  > *- **Idempotency Guard**: If `claim.getSubmittedAt() != null`, return immediately with 200 OK without re-inserting outbox records.*
  > *- **State Guard**: Ensure `claim.getClaimStatus() == ClaimStatus.PENDING` and reject any claim already under review or finalized.*
  > *- **Document Existence Guard**: Check `claimDocumentRepo.countByClaim_ClaimIdAndIsDeletedFalse(claimId) > 0` before accepting submission.*
  > *- **Atomic Outbox Persistence**: Set `submittedAt = Instant.now()`, update `fraudStatus = PENDING_ANALYSIS`, and commit the `OutboxEvent` within the exact same database transaction."*

---

### Q22: Why does mobile document & accident-photo upload to Cloud Storage (Cloudinary/S3) become extremely slow, and how is it optimized?
* **Interviewer Angle**: Mobile media pipelines, asymmetrical bandwidth, client-side downsampling, concurrency, and double-hop vs direct upload architectures.
* **Elevator Pitch**:
  > *"In mobile claim workflows, media upload latency is dominated by three compounding bottlenecks:*
  > *1. **Uncompressed High-Megapixel RAW Images**: Modern smartphone cameras (such as 50MP sensors) produce photos ranging from **6 MB to 15 MB** each. If a claimant attaches 3 accident photos and 2 documents, the app attempts to push **35 MB to 50 MB** of uncompressed data.*
  > *2. **The Double-Hop Proxy Penalty**: The mobile client uploads the files to the Spring Boot backend (`Hop 1`), and Spring Boot synchronously uploads the files over the public internet to Cloudinary/S3 (`Hop 2`). Because home broadband and mobile cellular networks have heavily asymmetrical bandwidth (upload speeds are often 5x to 10x slower than download speeds), this double transfer exhausts uplink capacity.*
  > *3. **Sequential Blocking Loops**: Uploading documents in a sequential `for (...) await upload()` loop forces the client to wait for round-trip latency on file $N$ before initiating file $N+1$. With four 10MB files taking 15s each, user-perceived latency reaches **60 seconds**.*
  > *The architectural solution achieves a **>90% latency reduction** through four optimizations:*
  > *- **Client-Side Downsampling & Quality Tuning**: In Flutter, set `maxWidth: 1920, maxHeight: 1080, imageQuality: 80` in the image picker. This slashes file sizes from **10 MB down to ~400 KB** (a 96% reduction in payload) while maintaining high DPI clarity for PyMuPDF OCR and AI damage detection.*
  > *- **Concurrent Parallel Dispatch**: Replace sequential loops with `Future.wait(docs.map(...))`, saturating the connection and executing all multipart uploads simultaneously.*
  > *- **Environment-Aware Storage Routing**: In local development, route files to a built-in `LocalStorageService` (`STORAGE_PROVIDER=local`) on the local disk (latency: < 20ms). In staging/production, route to Cloudinary/S3 CDN.*
  > *- **Direct-to-Cloud Uploads (S3 Presigned URLs / Cloudinary Upload Presets)**: For high-scale production, generate temporary presigned upload URLs so the mobile client pushes directly to the cloud storage bucket, eliminating backend proxy overhead entirely."*

---

### Q23: Why does calling a `@Transactional` method from another method in the same class fail to start a database transaction (Spring AOP Proxy Bypass)?
* **Interviewer Angle**: Spring AOP mechanics, dynamic proxies (CGLIB / JDK Dynamic Proxies), transaction interceptor lifecycle, and architectural workarounds.
* **Elevator Pitch**:
  > *"In Spring Boot, declarative transaction management is powered by **AOP (Aspect-Oriented Programming) Proxies**. When another bean calls a `@Transactional` method on `FraudAnalysisServiceImpl`, the invocation actually passes through a generated proxy wrapper that intercepts the call, starts or joins a transaction via `PlatformTransactionManager`, and commits or rolls back upon completion.*
  > *However, if a non-transactional method (e.g., `analyzeClaim()`) calls a transactional method in the **exact same class** via `this.persistResultsTransactional(...)`, the call is an internal Java `this` reference. It completely bypasses the Spring proxy and calls the raw target method directly.*
  > *As a consequence, the code inside `persistResultsTransactional()` runs with **zero active transaction**. If multiple repository operations (e.g., deleting previous flags and inserting new flags) are executed, they are either executed in auto-commit mode or fail midway without rollback, leaving the database in a corrupted partial state.*
  > *The clean architectural solution is **Bean Extraction**: move the transactional write logic into a dedicated, single-responsibility helper bean (e.g., `AnalysisResultWriter` or `ClaimDocumentWriter`) and inject it into the caller service. Every invocation then passes through Spring's proxy, ensuring strict ACID isolation without holding connections during slow external calls."*

---

### Q24: What is the concurrency risk of declaring instance fields in a Spring `@Service` or `@Component` bean?
* **Interviewer Angle**: Spring bean scopes (Singleton vs Prototype), thread safety, multi-threaded request processing, and servlet container thread pools (Tomcat/Hikari).
* **Elevator Pitch**:
  > *"By default, all Spring `@Service`, `@Component`, and `@RestController` beans are **singletons**—a single instance is created by the Spring `ApplicationContext` and shared across every concurrent worker thread in Tomcat.*
  > *If a developer declares a mutable instance variable (for example, `private StoredFileResult storedFileResult;` inside `ClaimDocumentServiceImpl`), that field is stored on the heap and shared across all concurrent HTTP requests.*
  > *If User A and User B upload documents concurrently:*
  > *1. User A's thread assigns `this.storedFileResult = resultA`.*
  > *2. User B's thread context-switches in and assigns `this.storedFileResult = resultB` before User A finishes saving.*
  > *3. User A's thread resumes and reads `this.storedFileResult`—saving User B's Cloudinary storage key and URL into User A's database record.*
  > *This results in severe data corruption and cross-tenant data leakage.*
  > *The rule in Spring applications: **Beans must remain stateless**. All request-scoped data must be maintained in method-local variables (stack memory) or passed explicitly as method arguments, ensuring complete thread isolation."*

---

### Q25: Why did messages sent to a Dead Letter Exchange (DLX) silently disappear, and why are RabbitMQ Queue arguments immutable?
* **Interviewer Angle**: RabbitMQ internals, AMQP protocol specifications, Dead Lettering mechanics, and migration patterns for live queue parameters.
* **Elevator Pitch**:
  > *"When configuring Dead Lettering in RabbitMQ, specifying only `x-dead-letter-exchange` causes RabbitMQ to republish dead-lettered messages to the DLX using the message's **original routing key** (e.g., `claim.submitted`).*
  > *If the Dead Letter Queue (DLQ) is bound to the DLX with a specific error routing key (such as `fraudguard.claim.analysis.dlq`), RabbitMQ cannot find a matching binding for `claim.submitted` on the DLX. Under AMQP protocol rules, unroutable messages on an exchange without an alternate exchange are **silently dropped and lost forever**.*
  > *The fix requires configuring the queue with `x-dead-letter-routing-key` pointing explicitly to `queue + ".dlq"`.*
  > *However, RabbitMQ enforces **Queue Argument Immutability**: once a queue is declared with an argument map, AMQP clients cannot alter its arguments (`x-dead-letter-routing-key`, `x-max-length`, `x-queue-type`). If an application redeploys with modified arguments, RabbitMQ raises `406 PRECONDITION_FAILED`.*
  > *To resolve this without downtime in production, developers either:*
  > *1. Use a **Blue-Green queue migration** (declare `fraudguard.claim.analysis.v2`, route new events to v2, drain v1, then delete v1).*
  > *2. In development/staging, delete the empty queue via the RabbitMQ Management HTTP API or CLI and let Spring AMQP re-declare it with the new configuration on boot."*

---

### Q26: Why should AI Fraud Detection systems be strictly Advisory rather than autonomously overwriting human claim verdicts?
* **Interviewer Angle**: Human-in-the-loop (HITL) system design, automated decision audits, false positive blast radius, and insurance compliance regulations.
* **Elevator Pitch**:
  > *"In production insurance claim systems, an automated AI microservice should never directly mutate human investigator fields (such as `claim.fraudStatus = CLEAR` or `APPROVED`).*
  > *If the AI pipeline autonomously marks a claim as `CLEAR` or `APPROVED`:*
  > *1. A false negative (e.g., subtle digital image doctoring that bypassed perceptual hashing) results in an irreversible unauthorized financial payout.*
  > *2. Conversely, a false positive (e.g., camera EXIF stripped by a chat app like WhatsApp) could unlawfully reject or accuse an honest claimant, violating regulatory fair-claims directives (e.g., IRDAI / state insurance commissioners).*
  > *3. It breaks the audit trail: when an investigator opens a claim, they cannot distinguish whether the verdict was made by an accredited human officer or an automated computer-vision heuristic.*
  > *In FraudGuard, we enforce a strict **Advisory Architecture**:*
  > *- The AI pipeline populates metadata fields: `fraudScore` (0-100), `aiRecommendation` (`FAST_TRACK`, `REVIEW`, `INVESTIGATE`), `aiRiskLevel`, `aiSummary`, and granular `ClaimEvidenceFlags`.*
  > *- The operational `fraudStatus` (e.g., `PENDING_ANALYSIS`, `UNDER_INVESTIGATION`, `RESOLVED`) and `claimStatus` remain strictly owned and updated by authenticated human investigators, preserving compliance and human-in-the-loop oversight."*

---

### Q27: When should you use `@Transactional` and when must you NOT use it in Spring Boot? (The 5 Golden Rules of Transaction Boundaries)
* **Interviewer Angle**: Transaction boundaries, connection pool lifecycle (HikariCP), ACID semantics vs distributed side effects, and architectural anti-patterns.
* **Elevator Pitch**:
  > *"A common mistake in Spring Boot is treating `@Transactional` as a generic safety blanket placed at the top of every service method. In high-throughput distributed systems, misplaced transactions cause severe performance collapse, connection starvation, and phantom rollbacks.*
  > *Here are the 5 architectural rules governing when to apply and when to avoid `@Transactional`:*

#### Rule 1: DO NOT use `@Transactional` around External Network & I/O Calls (The HikariCP Starvation Anti-Pattern)
* **Anti-Pattern**: Putting `@Transactional` on an orchestrator method that calls an AI microservice, uploads a file to S3/Cloudinary, or calls a payment gateway.
* **Why**: Spring's `TransactionInterceptor` borrows a physical JDBC connection from HikariCP **before** the method body begins. If that method waits 10 to 30 seconds for an AI response or Cloudinary upload, the physical DB connection sits completely idle and blocked.
* **Consequence**: Default HikariCP pool size is 10. Just 10 concurrent requests will exhaust the pool, causing all other incoming APIs (user login, policy viewing, health checks) to freeze with `CannotGetJdbcConnectionException: Connection is not available, request timed out after 30000ms`.
* **Fix**: Apply the **Read → Remote I/O → Write** pattern. Execute external I/O outside any transaction, then delegate DB writes to a dedicated transactional writer bean (`ClaimDocumentWriter`, `AnalysisResultWriter`) that holds a DB connection for only 10–15 milliseconds.
* **The Follow-Up Trap (`LazyInitializationException`)**: When you remove `@Transactional` from the outer method, Hibernate closes its `Session` as soon as the initial repository query returns. If your external I/O logic subsequently reads an uninitialized `LAZY` relation (such as `claim.getTenant().getTenantCode()` for Cloudinary folder paths), Hibernate throws `LazyInitializationException: Could not initialize proxy - no session`.
  * **Solution**: Eagerly fetch the necessary association at the repository layer using Spring Data JPA's `@EntityGraph(attributePaths = {"tenant"})` or a `JOIN FETCH` query. This populates the entity in a single SQL query so it remains safely accessible in memory long after the Hibernate session has closed.

#### Rule 2: DO NOT assume `@Transactional` can rollback External Side Effects
* **Anti-Pattern**: Placing `@Transactional` on a method thinking: *"If the AI service or email sender fails later, the transaction will undo everything."*
* **Why**: Database transactions only rollback **SQL mutations executed against that database**. A database rollback **cannot**:
  * Un-send an HTTP POST request already received by another server.
  * Delete a file already uploaded to Cloudinary/S3.
  * Recall an email or SMS sent via SMTP/Twilio.
* **Furthermore**: If an external call fails **before** any SQL writes occur (like `analyzeClaimAsync()` failing at `dispatchToAi()`), **there is literally zero database data to roll back**. Holding a transaction open for it was completely pointless.

#### Rule 3: DO use `@Transactional` on Multiple Atomic SQL Writes (All-or-Nothing ACID Guarantee)
* **When to Use**: Whenever two or more database write operations must succeed or fail together.
* **Examples in FraudGuard**:
  1. **Claim Submission & Outbox Pattern**:
     ```java
     claim.setSubmittedAt(Instant.now());
     claim.setFraudStatus(FraudStatus.PENDING_ANALYSIS);
     claimRepo.save(claim);
     outboxEventRepo.save(outboxEvent); // MUST commit together!
     ```
     If the Outbox event fails to insert, the claim status must roll back to `DRAFT/PENDING` so an untracked ghost claim is never created.
  2. **Persisting Analysis Results (`AnalysisResultWriter`)**:
     Updating the claim risk score, updating document pHashes, deleting previous evidence flags, and saving new evidence flags must all commit together in one atomic batch.

#### Rule 4: DO NOT use `@Transactional` on Single-Table Reads (Use `@Transactional(readOnly = true)` Only When Needed)
* **Anti-Pattern**: Adding `@Transactional` to simple repository reads like `findById()` or `findByUserAndIsDeletedFalse()`.
* **Why**: Every transaction incurs proxy interception, transaction manager thread-local context allocation, connection acquisition, and commit/rollback overhead.
* **When `readOnly = true` IS beneficial**:
  * Complex multi-table read operations requiring repeatable reads (Isolation level consistency).
  * Preventing Hibernate dirty checking overhead: Hibernate flushes its persistence context snapshot during commit unless `readOnly = true` instructs it to skip dirty checks.
  * Large queries initializing `LAZY` collections across multiple entities within the same session.

#### Rule 5: Watch out for Spring AOP Proxy Bypass (Self-Invocation)
* **Anti-Pattern**: Calling `@Transactional public void helperWrite()` from `public void orchestrator()` within the same class (`this.helperWrite()`).
* **Why**: Spring applies transaction interception via dynamic CGLIB/JDK proxies. Direct `this.` calls bypass the proxy wrapper, executing the method in raw Java with **zero transaction**, ignoring the annotation completely.
* **Fix**: Extract the write logic into an independent Spring bean (`AnalysisResultWriter`) and inject it.

---

### Q28: What is the `ObjectNode#setAll` Jackson Deserialization Trap in RabbitMQ Consumers, and how do you achieve header-agnostic messaging?
* **Interviewer Angle**: Spring AMQP message conversion lifecycle, Jackson 3.x tree AST deserialization bugs, `__TypeId__` header poisoning, and raw AMQP messaging patterns.
* **Elevator Pitch**:
  > *"When using Spring AMQP's `JacksonJsonMessageConverter`, passing a `JsonNode` (e.g. `objectMapper.readTree(payload)`) directly to `rabbitTemplate.convertAndSend()` causes the converter to automatically inject a message header: `__TypeId__ = com.fasterxml.jackson.databind.node.ObjectNode`.*
  > *When a `@RabbitListener` consumer attempts to receive this message via `@RabbitListener public void consume(JsonNode payload)` or via Jackson-managed parameter conversion, Jackson attempts to instantiate `com.fasterxml.jackson.databind.node.ObjectNode` through reflection.*
  > *In Jackson 2.15+ and Jackson 3.x, this throws an instant fatal exception:*
  > *`InvalidDefinitionException: Conflicting setter definitions for property "all": ObjectNode#setAll(ObjectNode) vs ObjectNode#setAll(Map)`.*
  > *Because `ObjectNode` is an internal AST node rather than a standard JavaBean, Jackson fails to resolve its overloaded setter methods.*
  > *The clean architectural solution is **Header-Agnostic Raw AMQP Messaging**:*
  > *1. **On the Publisher (`OutboxRelay`)**: Send raw JSON bytes using Spring's `MessageBuilder`:*
  >    ```java
  >    Message message = MessageBuilder
  >        .withBody(event.getPayload().getBytes(StandardCharsets.UTF_8))
  >        .setContentType(MessageProperties.CONTENT_TYPE_JSON)
  >        .setContentEncoding("UTF-8")
  >        .build();
  >    rabbitTemplate.send(exchange, routingKey, message);
  >    ```
  >    *This bypasses Jackson's automatic type stamping and avoids publishing misleading `__TypeId__` metadata.*
  > *2. **On the Consumer (`ClaimAnalysisConsumer`)**: Accept `org.springframework.amqp.core.Message message`:*
  >    ```java
  >    @RabbitListener(queues = "${rabbitmq.queue.claim.analysis}")
  >    public void consume(Message message) {
  >        String payload = new String(message.getBody(), StandardCharsets.UTF_8);
  >        JsonNode jsonNode = objectMapper.readTree(payload);
  >        Long claimId = jsonNode.get("claimId").asLong();
  >        ...
  >    ```
  >    *When the listener takes `org.springframework.amqp.core.Message`, Spring AMQP bypasses parameter conversion completely. The listener extracts raw bytes, parses them via `objectMapper.readTree()`, and remains completely immune to Jackson proxy or setter conflicts."*

---

### Q29: How do you prevent AI Analysis Storms, handle RabbitMQ Publisher Confirms in the Outbox Pattern, and guarantee Consumer Idempotency?
* **Interviewer Angle**: Distributed transaction boundaries, event storming hazards, asynchronous confirmation protocols, and database-level idempotency patterns.
* **Elevator Pitch**:
  > *"In an event-driven AI architecture, three critical pitfalls often emerge in production:*
  > 
  > *1. **The Premature AI Trigger & Verdict Overwrite Bug** :*
  > *   **Problem**: If document upload endpoints automatically emit `CLAIM_DOCUMENT_ADDED` and reset `fraudStatus = PENDING_ANALYSIS`, two major problems occur:*
  > *     a) When a user creates a claim and uploads 5 photos before submission, 5 redundant AI analysis runs trigger in parallel on an incomplete draft, wasting GPU/API resources and causing race conditions on flag tables.*
  > *     b) If an investigator has already marked a claim `CONFIRMED` or `CLEAR`, uploading an additional document wipes out the human investigator's verdict back to `PENDING_ANALYSIS`.*
  > *   **Solution**: Strict domain boundaries. Document upload NEVER touches `claim.fraudStatus`! AI analysis is strictly triggered at `POST /claims/{id}/submit`. For subsequent document uploads, `CLAIM_DOCUMENT_ADDED` is emitted **only** if `claim.getSubmittedAt() != null && claim.getClaimStatus() == ClaimStatus.PENDING`.*
  > 
  > *2. **The Outbox Relay Fire-and-Forget Silent Drop Bug** :*
  > *   **Problem**: In the Transactional Outbox Pattern, calling `rabbitTemplate.send(exchange, routingKey, msg)` without awaiting confirmation is merely a socket push. If the broker crashes, NACKs, or if the routing key is unroutable, the relay would still mark the event `PUBLISHED` in the database, resulting in silent, undetectable event loss.*
  > *   **Solution**: **Correlated Publisher Confirms + Mandatory Return Detection**:*
  > *   Enable `publisher-confirm-type=correlated`, `publisher-returns=true`, and `template.mandatory=true`. In `OutboxRelay`, pass `CorrelationData`:*
  > ```java
  > CorrelationData cd = new CorrelationData(String.valueOf(event.getEventId()));
  > rabbitTemplate.send(exchange, routingKey, message, cd);
  > 
  > CorrelationData.Confirm confirm = cd.getFuture().get(5, TimeUnit.SECONDS);
  > if (confirm == null || !confirm.isAck()) {
  >     throw new IllegalStateException("RabbitMQ NACK or timeout for event #" + event.getEventId());
  > }
  > if (cd.getReturned() != null) {
  >     throw new IllegalStateException("Unroutable message returned for event #" + event.getEventId());
  > }
  > event.setStatus(OutboxStatus.PUBLISHED);
  > ```
  > *   If a timeout, NACK, or unroutable return occurs, an exception is thrown, rolling back the lease, triggering exponential backoff retry (3^attempts seconds), and marking `DEAD` after 5 failed attempts.*
  > 
  > *3. **Centralized Outbox Pattern with `Propagation.MANDATORY`** :*
  > *   By enforcing `@Transactional(propagation = Propagation.MANDATORY)` in `OutboxServiceImpl`, calling code cannot write an outbox event unless an active database transaction already exists. If someone attempts to emit an event outside a transaction, Spring immediately throws `IllegalTransactionStateException`, preventing partial state saves.*
  > 
  > *4. **Consumer Idempotency via `ClaimAnalysisRun`** :*
  > *   To prevent redundant analysis upon message redelivery, `ClaimAnalysisConsumer` checks `claimAnalysisRunRepo.existsByOutboxEventId(eventId)`. Furthermore, `ClaimAnalysisRun` defines a database unique constraint on `(claim_id, run_version)`. If duplicate concurrent workers attempt to start the same run version, the database unique key violation atomically aborts the duplicate thread."*

---

*(This document is actively maintained as new architectural components are implemented in FraudGuard.)*



