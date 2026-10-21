# FraudGuard Database Architecture & Schema Design 🗄️

This document details the entity-relationship model and schema specifications for **FraudGuard** (MySQL 8.0 on Aiven Cloud).

---

## 📊 Entity Relationship Diagram (ERD)

```mermaid
erDiagram
    TENANTS ||--o{ USERS : "houses"
    TENANTS ||--o{ INSURANCE_PLANS : "offers"
    TENANTS ||--o{ POLICIES : "issues"
    TENANTS ||--o{ CLAIMS : "manages"

    USERS ||--o{ POLICIES : "owns"
    USERS ||--o{ CLAIMS : "files"
    USERS ||--o{ INVESTIGATIONS : "assigned_as_investigator"

    INSURANCE_PLANS ||--o{ POLICIES : "defines"
    
    POLICIES ||--o{ CLAIMS : "covers"

    CLAIMS ||--o{ CLAIM_DOCUMENTS : "contains"
    CLAIMS ||--o{ CLAIM_EVIDENCE_FLAGS : "flags"
    CLAIMS ||--o| INVESTIGATIONS : "triggers"

    TENANTS {
        bigint id PK
        varchar tenant_id UK
        varchar tenant_name
        varchar status
        timestamp created_at
    }

    USERS {
        bigint id PK
        varchar tenant_id FK
        varchar email UK
        varchar password_hash
        varchar full_name
        varchar role "ADMIN, INVESTIGATOR, CUSTOMER"
        timestamp created_at
    }

    INSURANCE_PLANS {
        bigint id PK
        varchar tenant_id FK
        varchar plan_name
        decimal idv_amount "Maximum Insured Declared Value"
        decimal annual_premium
        boolean is_active
    }

    POLICIES {
        bigint id PK
        varchar tenant_id FK
        bigint user_id FK
        bigint plan_id FK
        varchar policy_number UK
        varchar vehicle_number "e.g. MH12AB1234, KA53C1095"
        varchar vehicle_make
        varchar vehicle_model
        date start_date
        date end_date
        varchar status "ACTIVE, EXPIRED, CANCELLED"
    }

    CLAIMS {
        bigint id PK
        varchar tenant_id FK
        bigint user_id FK
        bigint policy_id FK
        varchar claim_number UK
        decimal claim_amount
        date incident_date
        varchar incident_city
        varchar incident_state
        decimal incident_latitude
        decimal incident_longitude
        varchar claim_status "SUBMITTED, UNDER_INVESTIGATION, APPROVED, REJECTED"
        varchar fraud_status "PENDING_ANALYSIS, LOW_RISK, MEDIUM_RISK, HIGH_RISK"
        decimal fraud_score "0.00 to 100.00"
        timestamp created_at
    }

    CLAIM_DOCUMENTS {
        bigint id PK
        bigint claim_id FK
        varchar document_type "FIR, INVOICE, VEHICLE_DOCUMENT, ACCIDENT_PHOTO"
        varchar file_url "Cloudinary HTTPS URL"
        varchar phash "16 hex-character perceptual hash for duplicate detection"
        varchar mime_type
        bigint file_size_bytes
        timestamp uploaded_at
    }

    CLAIM_EVIDENCE_FLAGS {
        bigint id PK
        bigint claim_id FK
        varchar flag_code "e.g. PHOTO_EXACT_DUPLICATE_DETECTED"
        varchar category "DOCUMENT_INCONSISTENCY, PHOTO_FORENSICS, CLAIM_RULES"
        varchar severity "LOW, MEDIUM, HIGH"
        varchar source "document-ocr, photo-forensics, claim-rules"
        text explanation
        decimal confidence
        timestamp created_at
    }

    INVESTIGATIONS {
        bigint id PK
        bigint claim_id FK
        bigint investigator_id FK
        varchar investigation_status "ASSIGNED, IN_PROGRESS, COMPLETED"
        varchar finding "CLEAR, SUSPECTED, CONFIRMED"
        text investigator_notes
        timestamp assigned_at
        timestamp completed_at
    }
```

---

## 🔑 Key Field Details for Fraud Intelligence

### 1. `claim_documents.phash` (Perceptual Hash Column)
- **Type**: `VARCHAR(16)`
- **Format**: 16 lowercase hexadecimal characters (e.g. `9eb67138673361a8`).
- **Purpose**: Enables $O(1)$ lookup for exact duplicate photos and Hamming distance comparisons for cross-claim image re-use detection across multiple policies and tenants.

### 2. `claims.fraud_score` & `claims.fraud_status`
- **`fraud_score`**: Numeric value between `0` and `100` computed by the AI microservice composite scoring formula.
- **`fraud_status`**:
  - `PENDING_ANALYSIS`: Initial state upon submission before AI processing completes.
  - `LOW_RISK`: Score $< 25$ with no medium/high flags (eligible for Fast-Track auto approval).
  - `MEDIUM_RISK`: Score $25 - 59$ or presence of a medium flag (desktop review required).
  - `HIGH_RISK`: Score $\ge 60$ or any high severity flag (investigator assignment mandatory).
