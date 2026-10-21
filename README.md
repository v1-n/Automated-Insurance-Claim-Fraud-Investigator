# 🛡️ FraudGuard — Automated Insurance Claim Fraud Investigator

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Java](https://img.shields.io/badge/Java-21-ED8B00?logo=openjdk&logoColor=white)](https://www.oracle.com/java/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.x-6DB33F?logo=springboot&logoColor=white)](https://spring.io/projects/spring-boot)
[![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white)](https://www.mysql.com/)
[![Docker](https://img.shields.io/badge/Docker-Enabled-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Download APK](https://img.shields.io/badge/Download-Android%20APK-brightgreen?logo=android&logoColor=white)](https://github.com/viveknarawade/Automated-Insurance-Claim-Fraud-Investigator/releases/latest/download/app-release.apk)

FraudGuard is an enterprise, multi-tenant automated insurance claim management and AI-powered fraud investigation platform. Built with **Spring Boot 3 (Java 21)** on the core backend, **FastAPI (Python 3.12)** for computer vision and OCR fraud forensics, and **Flutter** on mobile, it automates the full motor policy lifecycle, incident claim filing, multi-modal evidence analysis, and investigator casework.

---

## 📱 Download Android APK (Live Demo)

👉 **[Download FraudGuard Android APK (v1.0.0)](https://github.com/viveknarawade/Automated-Insurance-Claim-Fraud-Investigator/releases/latest/download/app-release.apk)**  
*(File size: ~56.9 MB, built with release tree-shaking and minification)*

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
    subgraph Frontend["Flutter Mobile App (Android)"]
        UI_Customer["Customer Portal\n(Buy Policy, File Claim)"]
        UI_Admin["Admin Dashboard\n(Manage Plans, Assign Cases)"]
        UI_Investigator["Investigator Portal\n(Inspect Evidence, Review)"]
    end

    subgraph Backend["Spring Boot 3 Backend (Java 21)"]
        Security["Spring Security (Stateless JWT & RBAC)"]
        TenantFilter["Tenant Data Isolation"]
        PolicyService["Policy Lifecycle Service"]
        ClaimService["Claim Management Service"]
        InvestigatorService["Investigator Workload Service"]
    end

    subgraph AIService["AI Fraud Inspection Microservice (FastAPI / Python 3.12)"]
        AuthGuard["Internal Auth Guard (X-Internal-Key)"]
        DocOCR["PyMuPDF + Tesseract OCR Engine\n- 4-State Vehicle Matcher\n- BNS vs IPC Legal Check"]
        PhotoForensics["Photo Forensics Engine\n- 64-bit pHash Duplicate Matching\n- EXIF Tampering / Photoshop Detection\n- Haversine GPS Distance Check"]
        Scorer["Composite Risk Scorer (0-100)\n- FAST_TRACK, REVIEW, INVESTIGATE"]
    end

    subgraph Storage["Cloud Infrastructure"]
        DB[(Aiven Cloud MySQL)]
        Cloudinary["Cloudinary Storage (FIR & Damage Photos)"]
        Brevo["Brevo Email Service"]
    end

    UI_Customer -->|REST API| Security
    UI_Admin -->|REST API| Security
    UI_Investigator -->|REST API| Security

    Security --> TenantFilter
    TenantFilter --> PolicyService
    TenantFilter --> ClaimService
    TenantFilter --> InvestigatorService

    PolicyService --> DB
    ClaimService --> DB
    ClaimService --> Cloudinary
    ClaimService --> Brevo

    ClaimService -->|Async Analysis (X-Internal-Key)| AuthGuard
    AuthGuard --> DocOCR
    AuthGuard --> PhotoForensics
    DocOCR --> Scorer
    PhotoForensics --> Scorer
    DocOCR -->|Stream HTTPS| Cloudinary
    PhotoForensics -->|Stream HTTPS| Cloudinary
```

---

## ✨ Key Features

### 1. Multi-Tenant Architecture & RBAC
* Complete data isolation per insurance tenant (`TATA_AIG`, `MAHI`, `MSIL`).
* Stateless JWT authentication with `@PreAuthorize` method security.

### 2. Multi-Modal AI Fraud Inspection
* **4-State Vehicle Registration Matcher**: Classifies matches into `MATCH` (clean), `NEAR` (minor OCR substitution), `MISMATCH` (conflicting license plate detected), or `NOT_FOUND`.
* **Cross-Claim Duplicate Photo Detection**: 64-bit Perceptual Hashing (pHash) with Hamming distance matching flags identical or cropped/re-saved photos across different claims and policies.
* **Photo EXIF & Tampering Forensics**: Detects photo manipulation software (Photoshop, GIMP, Canva) and checks camera make/model.
* **Graduated Timeline & GPS Distance**: Compares photo capture timestamps (IST) and EXIF GPS coordinates against claimed incident dates and locations ($>50\text{ km}$ distance threshold).
* **Legal Code Modernization**: Flags post-July-2024 FIRs that cite obsolete Indian Penal Code (IPC) sections instead of Bharatiya Nyaya Sanhita (BNS).

### 3. Motor Policy Lifecycle
* **Admin Master Plan Catalog**: Admins configure coverage limits (IDV) and annual premiums.
* **Vehicle Policy Activation**: Customers apply a plan to a specific vehicle registration number and make/model.
* **Duplicate Purchase Prevention**: Rejects duplicate active policy purchases for the same vehicle/plan.
* **Policy-Gated Claims**: Customers can only file a claim against an active, verified vehicle policy.

### 4. Investigation & Fraud Governance
* **Composite Risk Scoring**: Calculates claim risk score from $0$ to $100$ and assigns recommendations (`FAST_TRACK`, `REVIEW`, `INVESTIGATE`).
* **Explainable Evidence Flags**: Generates IRDAI-compliant structured evidence flags with benign explanations and recommended next steps for investigators.
* **Real-Time Workload Tracking**: Admins view active investigator caseloads to balance assignments.
* **Admin Gated Decision**: Final claim approval or rejection is gated until investigation review is completed.

---

## 🛠️ Tech Stack

* **Mobile App:** Flutter, Dart, Provider (State Management), Material 3, File Picker, HTTP Client
* **Backend:** Java 21, Spring Boot 3, Spring Data JPA / Hibernate, Spring Security (JWT)
* **AI Fraud Service:** Python 3.12, FastAPI, PyMuPDF, Tesseract OCR, PIL/Pillow, ImageHash, ExifRead, httpx
* **Database:** MySQL 8.0 on Aiven Cloud
* **Cloud & DevOps:** Docker, Render, Cloudinary (File Storage), Brevo (Transactional Email API)

---

## 📚 Documentation Index

Detailed architectural and technical documents are available in the [`docs/`](file:///home/vivek/Dev/Automated-Insurance-Claim-Fraud-Investigator/docs/) directory:
- [API Documentation](file:///home/vivek/Dev/Automated-Insurance-Claim-Fraud-Investigator/docs/api/api-documentation.md) — Complete endpoint specs, schemas, and flag taxonomies.
- [System Architecture](file:///home/vivek/Dev/Automated-Insurance-Claim-Fraud-Investigator/docs/architecture/system-design.md) — Service boundaries, asynchronous flows, and security models.
- [Database Schema Design](file:///home/vivek/Dev/Automated-Insurance-Claim-Fraud-Investigator/docs/architecture/database-design.md) — ERD diagrams, entities, and perceptual hash storage.
- [Project Memory & Milestones](file:///home/vivek/Dev/Automated-Insurance-Claim-Fraud-Investigator/docs/Memory.md) — Current state, completed features, and implementation roadmap.

---

## 💻 Local Setup & Build

### 1. Run Flutter Mobile App
```bash
cd fraudguard-mobile
flutter pub get
flutter run
```

### 2. Run Python AI Fraud Microservice
```bash
cd fraudguard-ai-service
python3 -m venv fraudguard-ai-service-venv
source fraudguard-ai-service-venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8000
```

### 3. Run Spring Boot Backend
```bash
cd fraudguard-backend
mvn clean spring-boot:run
```

---

## 👤 Author
**Vivek Narawade**  
* B.Tech in Artificial Intelligence & Data Science, AISSMS IOIT, Pune  
* [LinkedIn](https://www.linkedin.com/in/vivek-narawade-095a6431b/) • [GitHub](https://github.com/viveknarawade)