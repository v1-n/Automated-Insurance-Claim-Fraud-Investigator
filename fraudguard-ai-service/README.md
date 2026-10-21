# FraudGuard AI Service 🛡️

The AI fraud detection microservice for **FraudGuard — Automated Insurance Claim Fraud Investigator**. Built with FastAPI, PyMuPDF, and PIL/ImageHash, this service performs automated multi-modal fraud verification on vehicle insurance claims.

---

## 📌 Capabilities

1. **Document Verification (`POST /verify-document`)**
   - Digital text extraction and PyMuPDF Tesseract OCR fallback for scanned PDFs/images.
   - **4-State Vehicle Registration Matcher**:
     - `MATCH`: Exact or OCR-normalized (O/0, I/1, etc.) match.
     - `NEAR`: Plausible OCR character misread (similarity ≥ 78%, raises advisory `LOW` flag).
     - `MISMATCH`: Distinct conflicting plate found in document (raises `HIGH` flag).
     - `NOT_FOUND`: Vehicle registration absent from document (raises `HIGH` flag).
   - **Legal Code Verification**: Detects obsolete Indian Penal Code (IPC) references in post-July-2024 FIRs (requires Bharatiya Nyaya Sanhita / BNS).
   - Distinguishes network download failures (`_DOWNLOAD_FAILED`) from corrupt files (`_EXTRACTION_FAILED`).

2. **Accident Photo Forensics (`POST /inspect-photo`)**
   - **Perceptual Hashing (pHash)**: 64-bit image hashing with Hamming distance matching for exact duplicate (distance 0) and near-duplicate (distance ≤ 5) detection across claims.
   - **EXIF Metadata Inspection**: Camera make/model extraction, image software tampering detection (Photoshop, GIMP, Canva, etc.).
   - **Date Forensics**: Graduated tolerance checking between photo capture date and claimed accident date using India Standard Time (`Asia/Kolkata`).
   - **GPS Verification**: Haversine distance calculation between EXIF coordinates and claimed incident location (50 km proximity threshold).

3. **Full Claim Orchestration (`POST /api/v1/analyze-claim`)**
   - Orchestrates documents and photos concurrently using bounded `asyncio.gather` (semaphore limit = 4).
   - Validates claim-level rules: policy validity period, IDV vs claim amount, and IST incident date sanity checks.
   - Produces composite risk score (0–100), risk tier (`LOW`, `MEDIUM`, `HIGH`), recommendation (`FAST_TRACK`, `REVIEW`, `INVESTIGATE`), and explainable evidence flags.

---

## 🔐 Security & Internal Authentication

All business routes are protected by internal API key verification:

- **Header**: `X-Internal-Key: <secret>`
- **Fail-Closed Design**: If `AI_INTERNAL_KEY` is not configured and `AUTH_DISABLED` is not enabled, requests fail closed (HTTP 500 configuration error).
- **Constant-Time Comparison**: Uses `hmac.compare_digest` to prevent timing attacks.
- **Local Development**: Set `AUTH_DISABLED=true` in `.env` to bypass authentication during development.
- **Public Health Route**: `GET /health` is public and unauthenticated for container liveness probes.

---

## ⚙️ Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `AI_INTERNAL_KEY` | *(Required in prod)* | Shared secret key for internal service-to-service calls from Spring Boot. |
| `AUTH_DISABLED` | `false` | Set to `true` to disable internal authentication during local development. |
| `PORT` | `8000` | Port for the Uvicorn ASGI server. |
| `HOST` | `0.0.0.0` | Host interface to bind to. |

---

## 🌐 OCR Language Support

- The service currently defaults to English language OCR (`language="eng"`).
- To support multilingual regional documents (e.g., Hindi, Marathi, Kannada):
  1. Install additional Tesseract language data packages in the Dockerfile / OS (e.g. `tesseract-ocr-hin`, `tesseract-ocr-mar`).
  2. Specify multi-language OCR in PyMuPDF: `page.get_textpage_ocr(language="eng+hin")`.

---

## 🚀 Running Locally

```bash
# 1. Create and activate virtual environment
python3 -m venv fraudguard-ai-service-venv
source fraudguard-ai-service-venv/bin/activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Configure environment
cp .env.example .env

# 4. Start development server
uvicorn app.main:app --reload --port 8000
```

---

## 🐳 Running with Docker

```bash
# Build Docker image
docker build -t fraudguard-ai-service .

# Run container
docker run -p 8000:8000 -e AI_INTERNAL_KEY=my-secret-key fraudguard-ai-service
```

---

## 🧪 Running Automated Tests

```bash
python -m unittest discover -s tests -p "test_*.py" -v
```
