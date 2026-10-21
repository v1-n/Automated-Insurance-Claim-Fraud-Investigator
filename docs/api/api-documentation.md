# FraudGuard API Documentation 📡

Complete API specifications for the **FraudGuard AI Fraud Detection Microservice** and **Spring Boot Backend**.

---

## 🛡️ Part 1: FraudGuard AI Microservice (`FastAPI`)

- **Base URL (Local)**: `http://localhost:8000`
- **Default Content-Type**: `application/json`
- **Authentication**: `X-Internal-Key: <AI_INTERNAL_KEY>` (Required for all endpoints except `/health`)

---

### 1. Full Claim Analysis Orchestration

Runs multi-modal fraud detection across all uploaded documents, accident photos, and insurance policy ground truth.

- **Endpoint**: `POST /api/v1/analyze-claim`
- **Header**: `X-Internal-Key: <secret>`

#### Request Payload (`AnalyzeClaimRequest`)

```json
{
  "tenant_id": "TATA_AIG",
  "claim_id": 101,
  "claim_number": "TATA_AIG-2026-00001",
  "claim_amount": 75000.0,
  "ground_truth": {
    "vehicle_number": "KA53C1095",
    "policy_number": "POL-2026-9901",
    "policy_start_date": "2026-01-01",
    "policy_end_date": "2026-12-31",
    "idv_amount": 350000.0,
    "incident_date": "2026-10-19",
    "incident_city": "Bengaluru",
    "incident_state": "Karnataka",
    "incident_latitude": 12.9716,
    "incident_longitude": 77.5946
  },
  "documents": [
    {
      "claim_doc_id": 1,
      "document_type": "FIR",
      "document_url": "https://res.cloudinary.com/aafdcxyl/image/upload/v1792243937/Screenshot_from_2026-10-17_19-01-38_bpmjva.png"
    }
  ],
  "photos": [
    {
      "claim_doc_id": 2,
      "photo_url": "https://res.cloudinary.com/aafdcxyl/image/upload/v1792504507/insurance-fraud/TATA_AIG/TATA_AIG-2026-00001/e0uikapke5vylm54af1v.jpg",
      "existing_hashes": ["9eb67138673361a8"]
    }
  ]
}
```

#### Response (`AnalyzeClaimResponse`)

```json
{
  "claim_id": 101,
  "tenant_id": "TATA_AIG",
  "risk_score": 15,
  "risk_level": "MEDIUM",
  "recommendation": "REVIEW",
  "summary": "Medium Risk (Score 15/100): Claim contains discrepancies or unverified items requiring desktop review.",
  "flags": [
    {
      "flag_id": "FLAG-101-01",
      "code": "PHOTO_EDITING_SOFTWARE_DETECTED",
      "category": "PHOTO_FORENSICS",
      "severity": "MEDIUM",
      "source": "photo-forensics",
      "explanation": "Image metadata indicates manipulation with editing software: Adobe Photoshop Web.",
      "benign_explanations": ["User cropped, compressed, or resized image before uploading"],
      "next_steps": ["Request original, unedited photo directly from device gallery"],
      "confidence": 0.90
    }
  ],
  "details": {
    "total_documents_analyzed": 1,
    "total_photos_analyzed": 1,
    "document_summaries": [
      {
        "claim_doc_id": 1,
        "document_type": "FIR",
        "vehicle_verified": true,
        "text_length": 735
      }
    ],
    "photo_hashes": [
      {
        "claim_doc_id": 2,
        "phash": "9eb67138673361a8"
      }
    ]
  }
}
```

---

### 2. Accident Photo Forensics

Analyzes a single photo for perceptual hashing (pHash), EXIF metadata tampering, date graduated tolerance, and GPS coordinates.

- **Endpoint**: `POST /inspect-photo`
- **Header**: `X-Internal-Key: <secret>`

#### Request Payload (`PhotoInspectRequest`)

```json
{
  "tenant_id": "TATA_AIG",
  "claim_id": 101,
  "photo_id": 2,
  "photo_url": "https://res.cloudinary.com/aafdcxyl/image/upload/v1792504507/insurance-fraud/TATA_AIG/TATA_AIG-2026-00001/e0uikapke5vylm54af1v.jpg",
  "incident_context": {
    "incident_date": "2026-10-19T10:00:00",
    "incident_city": "Bengaluru",
    "incident_state": "Karnataka",
    "incident_latitude": 12.9716,
    "incident_longitude": 77.5946
  },
  "existing_hashes": ["9eb67138673361a8"]
}
```

#### Response (`PhotoInspectResponse`)

```json
{
  "photo_id": 2,
  "phash": "9eb67138673361a8",
  "exif_found": true,
  "is_manipulated": true,
  "forensic_details": {
    "camera_make": "motorola",
    "camera_model": "moto g84 5G",
    "captured_at": "2026:10:19 12:45:10",
    "software_tag": "Adobe Photoshop Web",
    "gps_latitude": null,
    "gps_longitude": null
  },
  "flags": [
    {
      "code": "PHOTO_EDITING_SOFTWARE_DETECTED",
      "severity": "MEDIUM",
      "explanation": "Image metadata indicates manipulation with editing software: Adobe Photoshop Web.",
      "benignExplanations": ["User cropped, compressed, or resized image before uploading"],
      "nextSteps": ["Request original, unedited photo directly from device gallery"]
    }
  ],
  "verification_status": "SUSPICIOUS",
  "summary": "Photo #2 analyzed (pHash: 9eb67138673361a8). Generated 1 forensic flag(s)."
}
```

---

### 3. Document Verification (OCR & Registration Check)

Inspects documents (FIR, Invoices, RC) using digital PDF extraction or PyMuPDF Tesseract OCR.

- **Endpoint**: `POST /verify-document`
- **Header**: `X-Internal-Key: <secret>`

#### Request Payload (`DocumentVerifyRequest`)

```json
{
  "tenant_id": "TATA_AIG",
  "claim_id": 101,
  "documents": [
    {
      "document_id": 1,
      "document_type": "FIR",
      "document_url": "https://res.cloudinary.com/aafdcxyl/image/upload/v1792243937/Screenshot_from_2026-10-17_19-01-38_bpmjva.png"
    }
  ],
  "ground_truth": {
    "vehicle_number": "KA53C1095",
    "incident_date": "2026-10-19"
  }
}
```

---

### 4. Health Check Probe

Container liveness and uptime check.

- **Endpoint**: `GET /health`
- **Authentication**: None (Public)
- **Response**:
  ```json
  {
    "status": "ok",
    "msg": "fraudguard ai service is running"
  }
  ```

---

## 📋 Flag Taxonomy & Severity Reference

| Flag Code | Category | Severity | Detection Trigger |
|-----------|----------|----------|-------------------|
| `PHOTO_EXACT_DUPLICATE_DETECTED` | PHOTO_FORENSICS | `HIGH` | Perceptual hash Hamming distance $= 0$ matching historical claim photo. |
| `PHOTO_PERCEPTUAL_NEAR_DUPLICATE` | PHOTO_FORENSICS | `HIGH` | Perceptual hash Hamming distance $\le 5$ (crop, resize, watermark). |
| `PHOTO_TAKEN_PRIOR_TO_INCIDENT` | PHOTO_FORENSICS | `HIGH` | EXIF capture date predates claimed incident date (pre-existing damage). |
| `PHOTO_LOCATION_MISMATCH` | PHOTO_FORENSICS | `HIGH` | Photo GPS is $>50\text{ km}$ away from claimed incident location. |
| `CLAIM_INCIDENT_OUTSIDE_POLICY_PERIOD`| CLAIM_RULES | `HIGH` | Incident date does not fall between policy start and end dates. |
| `INCIDENT_DATE_IN_FUTURE` | CLAIM_RULES | `HIGH` | Incident date occurs after current calendar date (evaluated in IST). |
| `{TYPE}_VEHICLE_MISMATCH` | DOCUMENT_INCONSISTENCY | `HIGH` | Conflicting vehicle registration plate found in uploaded document. |
| `{TYPE}_VEHICLE_NOT_FOUND` | DOCUMENT_INCONSISTENCY | `HIGH` | Claimed vehicle registration absent from uploaded document. |
| `PHOTO_EDITING_SOFTWARE_DETECTED` | PHOTO_FORENSICS | `MEDIUM` | EXIF Software tag identifies Photoshop, GIMP, Canva, Lightroom, etc. |
| `PHOTO_NO_EXIF_METADATA` | PHOTO_FORENSICS | `MEDIUM` | Image was stripped of EXIF (e.g. sent via WhatsApp or social media). |
| `PHOTO_SIGNIFICANT_CAPTURE_DELAY` | PHOTO_FORENSICS | `HIGH` | Photo taken $>7$ days after claimed incident date. |
| `PHOTO_INCIDENT_DATE_MISMATCH_MODERATE`| PHOTO_FORENSICS | `MEDIUM` | Photo taken 2 to 7 days after claimed incident date. |
| `{TYPE}_DOWNLOAD_FAILED` | DOCUMENT_INCONSISTENCY | `MEDIUM` | Network error or 404/500 HTTP status during file download. |
| `{TYPE}_EXTRACTION_FAILED` | DOCUMENT_INCONSISTENCY | `MEDIUM` | Blurry scan, 0 pages, or corrupted file unreadable by OCR. |
| `CLAIM_EXCEEDS_IDV` | CLAIM_RULES | `MEDIUM` | Claim amount exceeds total vehicle Insured Declared Value. |
| `FIR_OBSOLETE_LEGAL_CODE` | DOCUMENT_INCONSISTENCY | `MEDIUM` | FIR cites IPC for incidents occurring on or after 1 July 2024. |
| `{TYPE}_VEHICLE_NEAR_MATCH` | DOCUMENT_INCONSISTENCY | `LOW` | Minor OCR character substitution (e.g. O/0, I/1) with $\ge 82\%$ similarity. |
| `PHOTO_INCIDENT_DATE_MISMATCH_MINOR` | PHOTO_FORENSICS | `LOW` | Photo captured 1 day after incident (advisory review). |
| `PHOTO_CAPTURE_DATE_UNAVAILABLE` | PHOTO_FORENSICS | `LOW` | Camera EXIF exists but capture timestamp is unrecorded by device. |
