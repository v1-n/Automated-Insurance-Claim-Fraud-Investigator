# FraudGuard Project Memory & Status Tracker 🧠

**Last Updated:** October 2026  
**Repository:** [Automated-Insurance-Claim-Fraud-Investigator](https://github.com/viveknarawade/Automated-Insurance-Claim-Fraud-Investigator)

---

## 📌 1. Current State & Completed Milestones

### A. Python AI Microservice (`fraudguard-ai-service`) — Complete & Hardened ✅
A high-performance FastAPI service dedicated to multi-modal evidence inspection and insurance fraud detection:
- **Document Text & OCR Verification (`POST /verify-document`)**:
  - Digital PDF text extraction and PyMuPDF Tesseract OCR fallback for scanned police FIRs and repair invoices.
  - Offloaded CPU-blocking OCR processing to background threadpool (`asyncio.to_thread`).
  - **4-State Vehicle Registration Matcher**:
    - `MATCH`: Exact character match (clean, 0 flags).
    - `NEAR`: Visual/OCR character confusion (O↔0, I↔1, S↔5, B↔8, Z↔2) or $\ge 82\%$ plate similarity $\rightarrow$ raises advisory `LOW` severity `{TYPE}_VEHICLE_NEAR_MATCH` flag without failing verification.
    - `MISMATCH`: Conflicting license plate detected ($\ge 6$ chars, $<60\%$ similarity) $\rightarrow$ raises `HIGH` severity flag.
    - `NOT_FOUND`: Registration number absent from document $\rightarrow$ raises `HIGH` severity flag.
  - **Legal Code Modernization Rule**: Flags FIRs filed on/after 1 July 2024 citing obsolete IPC instead of Bharatiya Nyaya Sanhita (BNS).
  - **Failure Classification**: Distinctly tags `{TYPE}_DOWNLOAD_FAILED` (retryable network issues) vs. `{TYPE}_EXTRACTION_FAILED` (corrupt or illegible scans) at `MEDIUM` severity.
- **Accident Photo Forensics (`POST /inspect-photo`)**:
  - **Perceptual Hashing (pHash)**: 64-bit image hashing with Hamming distance calculation (exact duplicate at distance 0, near-duplicate / cropped / re-saved at distance $\le 5$).
  - **Metadata Forensics**: Camera make/model extraction, image software tampering detection (Photoshop, GIMP, Canva, Lightroom, etc.).
  - **Graduated Date Tolerance**: Checks EXIF `DateTimeOriginal` against claimed accident date (same day = 0 flags, 1 day = `LOW`, 2-7 days = `MEDIUM`, $>7$ days or prior date = `HIGH`).
  - **GPS Proximity**: Haversine distance verification between EXIF coordinates and claimed incident location (50 km threshold).
  - Uses India Standard Time (`Asia/Kolkata`) for all date comparisons.
- **Full Claim Orchestration (`POST /api/v1/analyze-claim`)**:
  - Concurrently processes all documents and photos using bounded `asyncio.gather` with `asyncio.Semaphore(4)`.
  - Full failure isolation: single corrupted file or bad URL never crashes claim analysis.
  - Claim-level business rules: policy period coverage validation, claim amount exceeding vehicle IDV, future incident date sanity check.
  - Composite risk scoring (0–100), risk tier (`LOW`, `MEDIUM`, `HIGH`), recommendation (`FAST_TRACK`, `REVIEW`, `INVESTIGATE`), and explainable PRD Section 16 evidence flags.
- **Security & Packaging**:
  - Internal API key verification (`X-Internal-Key` header) with `hmac.compare_digest` constant-time comparison.
  - Fail-closed design: returns HTTP 503 if unconfigured in production; explicit `AUTH_DISABLED=true` for local dev.
  - Production `Dockerfile` (Python 3.12-slim, non-root user `appuser`, Tesseract OCR, healthcheck).
  - Comprehensive automated test suite with **23 passing tests**.

### B. Spring Boot 3 Backend (`fraudguard-backend`) — Production Ready ✅
- Multi-tenant data isolation (`TATA_AIG`, `MAHI`, `MSIL`).
- JWT-based authentication and Role-Based Access Control (Admin, Investigator, Customer).
- Motor policy lifecycle management: plan catalogs, vehicle registration policy binding, duplicate purchase prevention.
- Claim filing intake with Cloudinary evidence storage and Brevo email notifications.

### C. Flutter Mobile Application (`fraudguard-mobile`) — Live Demo APK ✅
- Released v1.0.0 APK for Android.
- Role-gated workflows for Customer, Investigator, and Admin.
- In-app PDF and evidence image viewers.

---

## 🚀 2. Current Task & Next Phase: Spring Boot ↔ AI Service Integration

The next major milestone is connecting the Spring Boot backend to the Python AI service:
1. **Database Schema Update**:
   - Add `phash` column (`VARCHAR(16)`) to `claim_documents` table to persist perceptual hashes across claims for cross-claim duplicate detection.
2. **Spring Boot AI Client**:
   - Configure `RestClient` / `WebClient` in Spring Boot with `ai.fraud.service.url` and `ai.fraud.service.internal-key`.
   - Pass `X-Internal-Key` header on every request.
3. **Asynchronous Analysis Workflow**:
   - When a claim is submitted with documents and photos, trigger an `@Async` background job (or Transactional Outbox pattern).
   - Update `claims.fraud_score`, `claims.fraud_status`, and persist generated evidence flags.
4. **Notification Service Integration**:
   - Replace placeholder cards on Flutter `notifications_screen.dart` with live WebSocket/SSE or Polling notifications for high-risk alerts and review assignments.

---

## 🛠️ 3. Environment Variables Quick Reference

| Service | Variable | Purpose |
|---------|----------|---------|
| **AI Service** | `AI_INTERNAL_KEY` | Shared secret token for internal API access. |
| **AI Service** | `AUTH_DISABLED` | Set to `true` only for local offline dev. |
| **AI Service** | `PORT` | Listening port (default: 8000). |
| **Backend** | `AI_SERVICE_URL` | URL to `POST /api/v1/analyze-claim` (default: `http://localhost:8000/api/v1/analyze-claim`). |
| **Backend** | `AI_INTERNAL_KEY` | Must match the key set in the AI service. |