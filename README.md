# 🛡️ FraudGuard — Automated Insurance Claim Fraud Investigator

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Java](https://img.shields.io/badge/Java-21-ED8B00?logo=openjdk&logoColor=white)](https://www.oracle.com/java/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.x-6DB33F?logo=springboot&logoColor=white)](https://spring.io/projects/spring-boot)
[![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![RabbitMQ](https://img.shields.io/badge/RabbitMQ-3.x-FF6600?logo=rabbitmq&logoColor=white)](https://www.rabbitmq.com/)
[![Firebase](https://img.shields.io/badge/Firebase-FCM%20v1-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white)](https://www.mysql.com/)
[![Docker](https://img.shields.io/badge/Docker-Enabled-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Download APK](https://img.shields.io/badge/Download-Android%20APK%20(v1.1.0)-brightgreen?logo=android&logoColor=white)](https://github.com/v1-n/Automated-Insurance-Claim-Fraud-Investigator/releases/download/v1.1.0/FraudGuard-v1.1.0.apk)

FraudGuard is an enterprise, multi-tenant automated insurance claim management and AI-powered fraud investigation platform. Built with **Spring Boot 3 (Java 21)** on the core backend, **RabbitMQ** for event-driven decoupled pipelines, **FastAPI (Python 3.12)** for computer vision and OCR fraud forensics, and **Flutter** on mobile, it automates the full motor policy lifecycle, incident claim filing, multi-modal evidence analysis, real-time push/in-app alerts, and investigator casework.

---

## 📱 Download Android APK (Live Demo)

👉 **[Download FraudGuard Android APK (v1.1.0)](https://github.com/v1-n/Automated-Insurance-Claim-Fraud-Investigator/releases/download/v1.1.0/FraudGuard-v1.1.0.apk)**  
*(File size: ~58.6 MB, configured with live Render production backend, FCM push alerts, and in-app notifications)*

> 📦 **All Releases**: View release notes and previous builds on the [GitHub Releases page](https://github.com/v1-n/Automated-Insurance-Claim-Fraud-Investigator/releases).

---

## 🔑 Demo Login Credentials

You can test all 3 roles using these pre-configured credentials:

| Role | Email | Password | Tenant | Capabilities |
| :--- | :--- | :--- | :--- | :--- |
| **Admin** | `admin@fraudguard.com` | `admin123` | `TATA_AIG` | Create insurance plans, view all claims, assign investigators |
| **Investigator** | `investigator01@fraudguard.com` | `investigator123` | `TATA_AIG` | Review assigned claims, inspect evidence photos/FIRs, submit fraud reports |
| **Customer** | `customer@fraudguard.com` | `customer123` | `TATA_AIG` | Browse plans, activate vehicle policies (MH-12-AB-1234), file claims |

> **Note:** The backend is deployed live on Render: `https://fraudguard-backend-g3e4.onrender.com`. (Free tier backend may take 30-45 seconds to spin up on cold start).

---

## 🏗️ System Architecture

```mermaid
graph TD
    subgraph Frontend["Flutter Mobile App (Android / Material 3)"]
        UI_Customer["Customer Portal\n(Buy Policy, File Claim)"]
        UI_Admin["Admin Dashboard\n(Manage Plans, Assign Cases)"]
        UI_Investigator["Investigator Portal\n(Inspect Evidence, Review)"]
        UI_Notifications["In-App Notifications Screen\n(Unread Badge, Deep Linking)"]
        FCM_Client["Firebase Messaging Client\n(Heads-up Alerts, Token Sync)"]
    end

    subgraph Backend["Spring Boot 3 Core Backend (Java 21)"]
        Security["Spring Security (Stateless JWT & RBAC)"]
        TenantFilter["Tenant Data Isolation Filter"]
        ClaimService["Claim Management Service"]
        OutboxTable[("MySQL outbox_events\n(Transactional Outbox)")]
        OutboxRelay["Outbox Relay Poller\n(Publisher Confirms + Exponential Retries)"]
        NotificationService["In-App Notification Service"]
    end

    subgraph Broker["Event Broker Layer (RabbitMQ)"]
        Exchange{{"fraudguard.events (Topic)"}}
        QueueAI["fraudguard.claim.analysis\n(claim.submitted)"]
        QueuePush["fraudguard.notify.push\n(claim.*, ai.*, review.*)"]
        QueueDLQ["fraudguard.claim.analysis.dlx\n(Dead Letter Queue)"]
    end

    subgraph Workers["Asynchronous Consumers"]
        AIConsumer["ClaimAnalysisConsumer\n(Calls AI Service, Emits ai.analysis.ready)"]
        PushConsumer["PushNotificationConsumer\n(Persists In-App, Dispatches FCM)"]
        Sweeper["Stuck-Run Sweeper\n(Auto-recovers stalled analysis)"]
    end

    subgraph AIService["AI Fraud Inspection Microservice (FastAPI / Python 3.12)"]
        AuthGuard["Internal Auth Guard (X-Internal-Key)"]
        DocOCR["PyMuPDF + Tesseract OCR Engine\n- 4-State Vehicle Matcher\n- BNS vs IPC Legal Check"]
        PhotoForensics["Photo Forensics Engine\n- 64-bit pHash Duplicate Matching\n- EXIF Tampering / Photoshop Detection\n- Haversine GPS Distance Check"]
        Scorer["Composite Risk Scorer (0-100)\n- FAST_TRACK, REVIEW, INVESTIGATE"]
    end

    subgraph Storage["Cloud Infrastructure"]
        DB[(Aiven Cloud MySQL 8.0)]
        Cloudinary["Cloudinary CDN (Media & Documents)"]
        FCM["Firebase Cloud Messaging (FCM v1)"]
    end

    %% Client Interactions
    UI_Customer -->|REST API| Security
    UI_Admin -->|REST API| Security
    UI_Investigator -->|REST API| Security
    UI_Notifications -->|REST API| Security
    FCM_Client -->|POST /api/v1/devices| Security

    %% Core Flow
    Security --> TenantFilter
    TenantFilter --> ClaimService
    ClaimService -->|Atomic Transaction| DB
    ClaimService -->|Atomic Transaction| OutboxTable
    OutboxTable --> OutboxRelay
    OutboxRelay -->|Publish| Exchange

    %% Queue Routing
    Exchange -->|claim.submitted| QueueAI
    Exchange -->|claim.*, ai.*, review.*| QueuePush
    QueueAI -->|3 Failed Attempts| QueueDLQ

    %% Consumer Processing
    QueueAI --> AIConsumer
    QueuePush --> PushConsumer
    Sweeper --> DB

    %% AI Pipeline
    AIConsumer -->|POST /api/v1/analyze-claim| AuthGuard
    AuthGuard --> DocOCR
    AuthGuard --> PhotoForensics
    DocOCR --> Scorer
    PhotoForensics --> Scorer
    DocOCR -->|Stream Download| Cloudinary
    PhotoForensics -->|Stream Download| Cloudinary
    AIConsumer -->|Save Risk Score & Flags| DB

    %% Push Pipeline
    PushConsumer -->|Save In-App Notification| DB
    PushConsumer -->|Send Push Payload| FCM
    FCM -->|Push Banner| FCM_Client
```

---

## ✨ Key Features

### 1. Multi-Tenant Architecture & RBAC
* Complete data isolation per insurance tenant (`TATA_AIG`, `MAHI`, `MSIL`).
* Stateless JWT authentication with `@PreAuthorize` method security.

### 2. Transactional Outbox & Event-Driven Reliability
* **Transactional Outbox Pattern**: Eliminates dual-write failure modes by atomically committing business records and outbox events in the same MySQL transaction.
* **Correlated Publisher Confirms**: `OutboxRelay` verifies positive broker ACKs before marking outbox records `PUBLISHED`.
* **Dead Letter Queue (DLQ)**: Retries transient AI inspection failures up to 3 times with exponential backoff (5s, 15s, 45s) before isolating to `fraudguard.claim.analysis.dlx`.
* **Stuck-Run Sweeper**: Automatically audits and recovers claims stuck in `PENDING_ANALYSIS`.

### 3. Multi-Modal AI Fraud Inspection
* **4-State Vehicle Registration Matcher**: Classifies matches into `MATCH` (clean), `NEAR` (minor OCR substitution), `MISMATCH` (conflicting license plate detected), or `NOT_FOUND`.
* **Cross-Claim Duplicate Photo Detection**: 64-bit Perceptual Hashing (pHash) with Hamming distance matching flags identical or cropped/re-saved photos across different claims and policies.
* **Photo EXIF & Tampering Forensics**: Detects photo manipulation software (Photoshop, GIMP, Canva) and checks camera make/model.
* **Graduated Timeline & GPS Distance**: Compares photo capture timestamps (IST) and EXIF GPS coordinates against claimed incident dates and locations ($>50\text{ km}$ distance threshold).
* **Legal Code Modernization**: Flags post-July-2024 FIRs that cite obsolete Indian Penal Code (IPC) sections instead of Bharatiya Nyaya Sanhita (BNS).

### 4. Push & In-App Notification Hub
* **Firebase Cloud Messaging (FCM v1)**: Sends real-time heads-up notification banners to Android devices on critical events (`claim.submitted`, `claim.assigned`, `ai.analysis.ready`, `review.submitted`, `claim.approved`, `claim.rejected`).
* **In-App Notification Center**: Live inbox with dynamic unread counter badge on the mobile dashboard bell icon.
* **Smart Deep-Linking**: Tapping an in-app notification navigates directly to the role-specific claim screen (`ClaimDetailScreen`, `InvestigationDetailScreen`, or `AdminClaimDetailScreen`).
* **Event Idempotency**: Deduplicates notifications by `(eventId, recipientId)` to prevent duplicate inbox entries.

### 5. Motor Policy Lifecycle & Investigation Governance
* **Admin Master Plan Catalog**: Admins configure coverage limits (IDV) and annual premiums.
* **Vehicle Policy Activation**: Customers apply a plan to a specific vehicle registration number and make/model.
* **Composite Risk Scoring**: Calculates claim risk score from $0$ to $100$ and assigns recommendations (`FAST_TRACK`, `REVIEW`, `INVESTIGATE`).
* **Explainable Evidence Flags**: Generates IRDAI-compliant structured evidence flags with benign explanations and recommended next steps for investigators.
* **Admin Gated Decision**: Final claim approval or rejection is gated until investigation review is completed.

---

## 🛠️ Tech Stack

* **Mobile App:** Flutter 3.x, Dart, Provider (State Management), Firebase Messaging, `flutter_local_notifications`, Material 3, HTTP Client
* **Backend Core:** Java 21, Spring Boot 3, Spring Data JPA / Hibernate, Spring Security (JWT), Spring AMQP (RabbitMQ)
* **Message Broker:** RabbitMQ 3.x (CloudAMQP in production)
* **AI Fraud Service:** Python 3.12, FastAPI, PyMuPDF, Tesseract OCR, PIL/Pillow, ImageHash, ExifRead, httpx
* **Database:** MySQL 8.0 on Aiven Cloud
* **Cloud & DevOps:** Docker, Render, Cloudinary (File Storage), Firebase Admin SDK (FCM)

---

## 🚀 Cloud Deployment Guide (Render)

### 1. RabbitMQ Broker (CloudAMQP)
1. Create a free **Little Lemur** shared instance on [CloudAMQP](https://www.cloudamqp.com/).
2. Copy the host, port, username, and password into your environment variables.

### 2. Deploy AI Fraud Microservice on Render
1. Create a new **Web Service** on Render pointing to your GitHub repository (`dev` or `main`).
2. Set **Root Directory** to `fraudguard-ai-service`.
3. Set **Runtime** to `Docker` (Render automatically uses `fraudguard-ai-service/Dockerfile`).
4. Add Environment Variables:
   ```env
   PORT=8000
   AI_INTERNAL_KEY=your-secure-shared-secret-key
   ```
5. Note the deployed URL (e.g. `https://fraudguard-ai-service.onrender.com`).

### 3. Deploy Spring Boot Backend on Render
1. Create a new **Web Service** on Render.
2. Set **Root Directory** to `fraudguard-backend`.
3. Set **Runtime** to `Docker` (uses `fraudguard-backend/Dockerfile`).
4. Add Environment Variables:
   ```env
   SERVER_PORT=8081
   DB_URL=jdbc:mysql://<aiven-mysql-host>:3306/insurance_fraud_db?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true
   DB_USER=root
   DB_PASSWORD=<your-db-password>
   JWT_SECRET=<your-64-char-jwt-secret>
   
   # AI Service Connection
   AI_SERVICE_URL=https://fraudguard-ai-service.onrender.com/api/v1/analyze-claim
   AI_FRAUD_SERVICE_INTERNAL_KEY=your-secure-shared-secret-key

   # RabbitMQ Connection (CloudAMQP)
   RABBITMQ_HOST=<your-cloudamqp-host>
   RABBITMQ_PORT=5672
   RABBITMQ_USER=<your-cloudamqp-user>
   RABBITMQ_PASSWORD=<your-cloudamqp-password>

   # Storage Provider (Cloudinary)
   STORAGE_PROVIDER=cloudinary
   CLOUDINARY_CLOUD_NAME=<your-cloud-name>
   CLOUDINARY_API_KEY=<your-api-key>
   CLOUDINARY_API_SECRET=<your-api-secret>

   # Firebase Push Notifications (Paste raw JSON or upload via Render Secret File)
   FIREBASE_CREDENTIALS_JSON=<full-firebase-adminsdk-json-string>
   ```

---

## 💻 Local Setup & Build

### 1. Run RabbitMQ via Docker
```bash
docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:3-management
```

### 2. Run Python AI Fraud Microservice
```bash
cd fraudguard-ai-service
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8000
```

### 3. Run Spring Boot Backend
```bash
cd fraudguard-backend
mvn clean spring-boot:run
```

### 4. Run Flutter Mobile App
```bash
cd fraudguard-mobile
flutter pub get
flutter run
```

---

## 📚 Documentation Index

Detailed architectural and technical documents are available in the [`docs/`](docs/) directory:
- [System Architecture & Event Pipelines](docs/architecture/system-design.md) — Service boundaries, Outbox pattern, sequence diagrams, and DLQ specifications.
- [API Documentation](docs/api/api-documentation.md) — Complete endpoint specs, schemas, and flag taxonomies.
- [Database Schema Design](docs/architecture/database-design.md) — ERD diagrams, entities, and perceptual hash storage.
- [Project Memory & Milestones](docs/Memory.md) — Current state, completed features, and implementation roadmap.

---

## 👤 Author
**Vivek Narawade**  
* B.Tech in Artificial Intelligence & Data Science, AISSMS IOIT, Pune  
* [LinkedIn](https://www.linkedin.com/in/vivek-narawade-095a6431b/) • [GitHub](https://github.com/viveknarawade)