# FraudGuard — Product Requirements Document (PRD)

| | |
|---|---|
| **Product** | FraudGuard — Automated Insurance Claim Fraud Investigator |
| **Owner** | Vivek Narawade |
| **Status** | v1.0 shipped (core workflow). AI/ML layer is **planned**. |
| **Last updated** | TODO(Vivek): date |
| **Repo** | https://github.com/v1-n/Automated-Insurance-Claim-Fraud-Investigator |

> Legend used everywhere in these docs: ✅ Implemented · 🟡 Partial · 🔲 Planned

---

## 0. Project in 60 seconds (read this first, humans and AI assistants)

**What it is.** FraudGuard is a multi-tenant **AI-assisted claim investigation and evidence-verification platform for Indian motor insurance**. It is *not* an auto-adjudication system and *not* a fraud-accusation engine.

**What exists today (✅).** Spring Boot 4 / Java 21 REST API, MySQL, JWT auth with rotating refresh tokens, 3 roles (`USER` customer, `INVESTIGATOR`, `ADMIN`), 3 tenants (`TATA_AIG`, `MAHI`, `MSIL`), policy plans and activation, claim filing, evidence upload (Cloudinary), investigator assignment, investigator fraud verdict (`CLEAR`/`SUSPECTED`/`CONFIRMED`, entered **by hand**), admin approve/reject, Flutter mobile app, React web app. Fraud detection today is 100% manual.

**What we are building (🔲).** An AI layer of separate FastAPI services that checks documents and photos, applies India-specific rules, scores risk, and shows the investigator **evidence-anchored flags**: which document/page/field or policy date triggered each alert, plausible innocent explanations, and what to verify next.

**Core principles (do not violate when generating code or text):**
1. **AI advises, a human decides.** No automatic approval, rejection, or "fraud" label. Only an investigator records a verdict and only an admin decides.
2. **Every flag cites evidence.** A flag without a document/field/policy reference is not allowed. A bare score ("85% risk") is never the only output.
3. **Flags are not accusations.** Each flag lists benign explanations and a next verification step. Customers never see scores or flag details, only neutral requests.
4. **Spring Boot is the source of truth.** AI services are stateless, never read the main database, and never talk to the mobile app. Spring dispatches async jobs and stores results. Claim filing never waits on AI; if AI is down the claim proceeds as `UNSCORED`.
5. **Tenant isolation is absolute.** Every query and every AI job carries `tenant_id`. No cross-tenant data access.
6. **Be honest about data.** There is no real labelled fraud data. Training/evaluation uses a published synthetic generator and a few redacted samples; metrics always say so.
7. **Minimise personal data.** No Aadhaar or full licence numbers stored; only what a check needs. Design for India's DPDP Act.

**Where things live.** `insurance-fraud-backend/` (API), `insurance_flutter_app/` (mobile), `insurance-frontend/` (web), `fraudguard-ai/` (FastAPI, currently a `/health` skeleton), `docs/` (this folder). Read `Memory.md` for known bugs before changing code, `architecture/` for design, `api/` for endpoints.

**Domain vocabulary.** IDV (insured declared value, max payout basis) · FIR (police First Information Report) · RC (registration certificate) · NCB (no-claim bonus) · surveyor (IRDAI-licensed loss assessor) · IIB (Insurance Information Bureau) · BNS (Bharatiya Nyaya Sanhita, replaced the IPC on 1 July 2024) · GSTIN (15-character GST ID with a checksum digit) · break-in (policy renewed after a lapse).

---

## 1. Problem

Motor-insurance companies receive claims with supporting evidence (accident photos, FIR copies, repair estimates). Fraud (inflated amounts, early-policy claims, reused photos, forged FIRs) is currently caught by manual review. Small insurers have no tooling that lets them (a) run claims for several brands on one platform, (b) assign investigators fairly, and (c) keep a trustworthy audit of who decided what and why.

## 2. Vision

One multi-tenant platform where a customer files a claim from a phone with guided evidence capture, an admin routes it to an investigator, and the investigator reviews **evidence-anchored AI flags** (what was found, where, why it matters, what to check next) before recording a verdict and the admin makes the final decision. Humans spend their time on the claims that need it, and honest customers are not treated as suspects.

**Positioning statement:** *An explainable, evidence-anchored claim investigation platform for Indian motor insurance: it verifies documents against policy and claim data, applies India-specific checks, and tells investigators what to verify next. AI advises, a human decides.*

## 3. Goals and non-goals

### Goals
1. End-to-end motor claim lifecycle: policy → claim → evidence → investigation → decision. ✅
2. Strict data isolation between insurance tenants (`TATA_AIG`, `MAHI`, `MSIL`). 🟡
3. Explainable fraud flags (reason codes, not a black-box score). 🔲
4. Document verification (OCR + cross-check against claim/policy). 🔲
5. Run on free-tier infrastructure (Render, Aiven, Cloudinary, Hugging Face). ✅

### Non-goals (v1)
- Payment/settlement of approved claims.
- Non-motor lines (health, life, property).
- Automatic approval or rejection by AI. AI is **advisory only**; a human always decides.
- iOS release (Flutter code supports it; only an Android APK is built).
- Damage-cost estimation from photos (existing insurer tools do this; needs large labelled image data).
- Declaring a customer fraudulent, or showing customers risk scores or flag details.
- Real RC / driving-licence / Vahan / IIB lookups (need official API access). Build adapters with mock implementations only.
- Claiming IRDAI compliance. Say "designed around the IRDAI 2025 fraud monitoring framework."

## 4. Users and personas

| Persona | Role code | What they need |
|---|---|---|
| **Customer** (policyholder) | `USER` | Buy a policy for a vehicle, file a claim with evidence, track status. |
| **Investigator** | `INVESTIGATOR` | See only assigned claims, inspect evidence, record notes + fraud verdict. |
| **Admin** (insurer staff) | `ADMIN` | Maintain plan catalog, see all tenant claims, assign investigators by workload, make final decision. |

Rules: self-registration always creates a `USER`. Admin and investigator accounts are seeded by SQL (`seed_users.sql`). Every user belongs to exactly one tenant.

## 5. User stories

### Customer
- As a customer, I register with my tenant code, verify my email, and log in. ✅
- As a customer, I browse my insurer's plans and activate one for my vehicle. ✅
- As a customer, I file a claim against my active policy with incident details. ✅
- As a customer, I upload photos / FIR / estimates (PDF, PNG, JPG, ≤10 MB) and can remove them. ✅
- As a customer, I see my claim's status and the decision notes. ✅
- As a customer, I get notified when my claim status changes. 🔲 (push/email; current in-app events are local only)

### Investigator
- As an investigator, I see only claims assigned to me. ✅
- I open evidence in-app (image/PDF viewer). ✅
- I submit review notes and a verdict: `CLEAR`, `SUSPECTED`, `CONFIRMED`. ✅
- I see AI-generated flags and reasons next to the evidence. 🔲

### Admin
- As an admin, I see a dashboard of claim counts by status and fraud outcome. ✅
- I see unassigned claims and each investigator's workload, then assign one. ✅
- I approve or reject a claim only after the investigation is done; confirmed-fraud claims cannot be approved. ✅
- I create plans (type, max IDV, annual premium) and can issue a policy directly to a user. ✅
- I can audit every status change on a claim. 🔲

## 6. Functional requirements

| ID | Requirement | Status |
|---|---|---|
| **AUTH-1** | Register with email, name, password (≥8), tenant code; account is `PENDING` until email verified | ✅ |
| AUTH-2 | Email verification and resend; password reset via emailed token | ✅ |
| AUTH-3 | Login returns 15-min access JWT + 7-day refresh JWT; refresh tokens rotate and old ones are revoked | ✅ |
| AUTH-4 | Logout revokes refresh token; change password; soft-delete account | ✅ |
| AUTH-5 | Rate-limit login and reset endpoints | 🔲 |
| **TEN-1** | Every query for admin/investigator/customer is scoped to the caller's tenant | 🟡 (enforced per repository method, no global filter) |
| **POL-1** | Admin creates plans: name, type (`MOTOR_COMPREHENSIVE`, `MOTOR_THIRD_PARTY`, `MOTOR_ZERO_DEP`), max IDV, annual premium | ✅ |
| POL-2 | Customer activates a plan for a vehicle number + make/model; policy runs 365 days; policy number `POL-<TENANT>-<YEAR>-<ID>` | ✅ |
| POL-3 | Block duplicate active purchase of the same plan | ✅ (per plan, **not** per vehicle) |
| POL-4 | Admin can issue a policy directly to a customer with a custom IDV | ✅ |
| **CLM-1** | Claim only against an active policy; number `<TENANT>-<YEAR>-<ID>` | ✅ |
| CLM-2 | Claim fields: type, amount, description (10–1000 chars), incident date/address/city/state | ✅ |
| CLM-3 | Validate incident date is in the past and inside the policy period; amount ≤ IDV; let the customer pick which policy | 🔲 |
| CLM-4 | Paginated, sortable lists (created, amount, incident date, status) | ✅ |
| **DOC-1** | Upload PDF/PNG/JPG up to 10 MB with a document type (`ACCIDENT_PHOTO`, `FIR`, `VEHICLE_DOCUMENT`, `POLICY_DOCUMENT`, `MEDICAL_REPORT`, `REPAIR_ESTIMATE`, `INVOICE`, `OTHER`) | ✅ |
| DOC-2 | Storage via Cloudinary (prod) or local disk (dev), swappable by config | ✅ |
| DOC-3 | Verify file content by magic bytes, virus-scan status (`SCANNING`, `INFECTED`) | 🔲 (enum exists, no scanner) |
| **INV-1** | Admin assigns an investigator from the same tenant; a claim cannot be reassigned; claim moves to `UNDER_REVIEW` | ✅ |
| INV-2 | Investigator submits notes + verdict once; claim must be `UNDER_REVIEW` and verdict still `PENDING_ANALYSIS` | ✅ |
| INV-3 | Admin sees workload: active claims and completed reviews per investigator | ✅ |
| **DEC-1** | Approve/reject requires `UNDER_REVIEW` and a finished investigation; `CONFIRMED` fraud cannot be approved | ✅ |
| DEC-2 | Keep the investigator's verdict separate from the admin's decision | 🔲 (today admin decision overwrites `fraud_status`) |
| **AI-1** | Rule engine on claim creation: claim within 30 days of policy start, amount > 70% of IDV, incident outside policy period, long filing delay, no FIR on accident/theft, night-time incident. Produces flags with reason codes | 🔲 |
| AI-2 | Document verification: OCR (digital PDF via pymupdf, scans via Tesseract `eng+hin+mar`), extract vehicle number / date / FIR number / names, compare to policy and claim | 🔲 |
| AI-3 | Photo checks: perceptual-hash duplicate detection, EXIF date/GPS vs claimed incident, gallery-vs-live detection | 🔲 |
| AI-4 | ML risk model (XGBoost + SHAP) over rule and claim features; versioned; trained on synthetic data plus investigator verdicts | 🔲 |
| AI-5 | Network checks: claims sharing garage, phone or vehicle (NetworkX) | 🔲 |
| AI-6 | LLM-written case summary for investigators, structured output, advisory only, never shown to customers | 🔲 |
| AI-7 | Async dispatch via `ai_analysis_job` table, callback endpoint, retries, `UNSCORED` fallback | 🔲 |
| **EVD-1** | **Evidence-anchored flag**: every flag has `code`, `severity`, `category`, `evidence[]` (document id + page + bbox, or policy field), `explanation`, `benignExplanations[]`, `nextSteps[]`, `status` (see section 16) | 🔲 |
| EVD-2 | Investigator evidence viewer draws flag bounding boxes over the PDF/photo and links each flag to its evidence | 🔲 |
| EVD-3 | Investigator can mark a flag `CONFIRMED`, `DISMISSED` (with reason) or `NEEDS_INFO`; this feedback is training and evaluation data | 🔲 |
| **IND-1** | India validators: vehicle-number format (state series and BH series), GSTIN format + checksum, FIR number format | 🔲 |
| IND-2 | IPC vs BNS check: FIR for an incident on or after 1 July 2024 should cite BNS sections; mismatched or old-code sections raise a flag | 🔲 |
| IND-3 | Garage invoice checks: GSTIN valid, CGST+SGST arithmetic, parts + labour = total, invoice date not before incident, total vs claimed amount | 🔲 |
| IND-4 | Policy-timing checks: claim soon after renewal following a lapse (break-in), claim in first 30 days, NCB misuse | 🔲 |
| IND-5 | Place consistency: photo GPS/EXIF city vs claimed incident city | 🔲 |
| IND-6 | Garage pattern analysis: repeated high-value claims through the same workshop | 🔲 |
| IND-7 | `VerificationAdapter` interface (RC, licence, IIB history) with mock implementations; real integrations are out of scope | 🔲 |
| **VER-1** | Verification-request loop: investigator asks the customer for a specific document; states `REQUESTED → CUSTOMER_RESPONDED → RESOLVED / UNRESOLVED`; due date and SLA timer | 🔲 |
| VER-2 | Customer sees only neutral wording ("please upload your original repair estimate"), never flags or scores | 🔲 |
| VER-3 | SLA clocks: surveyor allocation within 24 h and report within 15 days for claims above ₹50,000 | 🔲 |
| **CAP-1** | Guided capture in Flutter: checklist (four corners, damage close-up, odometer, number plate, chassis plate, FIR, estimate), on-device blur check, camera-only capture, timestamp + GPS | 🔲 |
| CAP-2 | Compression and resumable upload for poor networks; Hindi and Marathi UI option | 🔲 |
| **TRI-1** | Triage lanes: low-risk claims under ₹50,000 are *recommended* for fast-track; a human still confirms. High-risk claims are routed to a senior investigator queue | 🔲 |
| **REG-1** | Red-flag library with each flag code mapped to a category from the IRDAI 2025 framework (policyholder/claims fraud, etc.) | 🔲 |
| REG-2 | Exportable fraud register (FMR-1-style) and immutable audit trail (`claim_status_history`) for the insurer's fraud monitoring unit | 🔲 |
| **SYN-1** | Open synthetic Indian motor-claim generator (claims, FIRs incl. Hindi/Marathi, garage invoices, photos) with injected fraud patterns | 🔲 |
| SYN-2 | Evaluation harness reporting precision, recall, precision@k and investigator-time-saved; every report states the data is synthetic | 🔲 |
| **AUD-1** | `claim_status_history` audit trail | 🔲 |

## 7. Claim lifecycle

```
PENDING ──(admin assigns investigator)──► UNDER_REVIEW
                                              │
              investigator verdict:  PENDING_ANALYSIS → CLEAR | SUSPECTED | CONFIRMED
                                              │
                         ┌────────────────────┴───────────────────┐
              admin approve (not if CONFIRMED)               admin reject
                         ▼                                        ▼
                     APPROVED                                 REJECTED
```
`INVESTIGATION_COMPLETED` and `CLOSED` exist in the enum but are not set by any workflow today.

## 8. Non-functional requirements

| Area | Requirement | Current |
|---|---|---|
| Security | JWT access ≤15 min, refresh rotation, BCrypt passwords, role + tenant checks on every endpoint | ✅ |
| Privacy | Evidence only visible to the owner, the assigned investigator, and same-tenant admin | ✅ |
| Availability | Free-tier Render cold start 30–45 s is acceptable; app shows a loading state | 🟡 |
| Performance | List endpoints paginated (default 10); target p95 < 500 ms warm | TODO(Vivek): measure |
| AI latency | AI analysis is asynchronous and never blocks claim filing | 🔲 |
| Resilience | If an AI service is down the claim still succeeds, marked `UNSCORED` | 🔲 |
| Quality | Unit + integration tests, CI on every push | 🔲 |
| Observability | Health endpoint ✅; structured logs, metrics 🔲 |

## 9. Success metrics

| Metric | Target | Measured |
|---|---|---|
| Time from claim filed to investigator assigned | TODO | TODO |
| % claims with complete evidence at submission | TODO | TODO |
| AI flag precision on the labelled test set (synthetic + real-sample) | TODO(≥0.80) | TODO |
| AI flag recall on the same set | TODO | TODO |
| Investigator time per claim with vs. without AI flags | TODO | TODO |

Be explicit in the README about what data the model was evaluated on. Synthetic data inflates scores.

## 10. Assumptions and constraints

- Single country (India), motor policies only, INR amounts.
- Free-tier hosting: 512 MB RAM on Render, so heavy ML (Tesseract, PyTorch) runs in separate services.
- No real customer data; the demo uses seeded accounts.

## 11. Roadmap

| Phase | Scope | Exit criteria |
|---|---|---|
| **0 — Hardening** | Fix known issues in `Memory.md` (upload race, cross-tenant plan purchase, token refresh, verdict overwrite, claim validations), tests, CI, README links | CI green, cross-tenant test passes |
| **1 — AI foundation + evidence flags** | `ai_analysis_job`, async dispatcher, callback endpoint, flag schema and storage (EVD-1), rule engine (AI-1), India validators (IND-1) | A new claim produces stored flags with reasons |
| **2 — Document verification + viewer** | FIR/invoice OCR and cross-checks (AI-2, IND-2, IND-3), evidence viewer with bounding boxes (EVD-2, EVD-3) | A mismatching FIR is highlighted on the page with next steps |
| **3 — Workflow** | Verification-request loop and SLA clocks (VER), guided capture (CAP), audit trail (REG-2), triage lanes (TRI) | Investigator requests a document; customer responds in-app |
| **4 — Data and ML** | Synthetic generator and evaluation harness (SYN), XGBoost + SHAP (AI-4), versioned models | Metrics documented honestly as synthetic |
| **5 — Advanced** | Duplicate photos and EXIF (AI-3), garage and ring graph (AI-5, IND-6), LLM summary (AI-6), retrain from investigator feedback | Demo-ready end-to-end |

## 12. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| No real labelled fraud data | Model quality overstated | Use synthetic data openly; lead with rules and explainability |
| Free-tier cold starts across several services | Poor demo | Async jobs, "analysis in progress" UI, keep-alive ping |
| Cross-tenant data leak from a missed filter | Critical | Hibernate tenant filter + integration tests |
| AI false positives harm honest customers | Trust | Advisory only, human decision, reason codes shown |
| Secrets in a public repo | Account compromise | Remove default JWT secret, rotate, env vars only |

## 13. Open questions

- TODO(Vivek): Will admins be able to manage tenants and users from the UI, or stay seed-only? (The React app has pages for them but the backend has no endpoints.)
- TODO(Vivek): Which public vehicle-insurance-fraud dataset will seed the ML model?
- TODO(Vivek): Is the React web app (`insurance-frontend`) in scope for v1 or an experiment?

---

## 14. India market and regulatory context

Facts below were checked against public sources on 2026-10-16. Re-check before quoting them in the README or an interview.

| Fact | Source |
|---|---|
| On 16 Dec 2025, in a written Lok Sabha reply on fraudulent practices in car-insurance claim settlement, the Finance Ministry said motor losses under ₹50,000 need not be surveyed by a registered surveyor and that insurers use app-based, AI-driven assessment for them. It is a description of practice, not a new rule. | Upstox report of the reply (PIB release itself not opened) |
| Motor losses above ₹50,000 must be surveyed. Surveyor allocated within 24 h; report within 15 days; ₹500/day payable to the claimant for delay. | same |
| IRDAI Insurance Fraud Monitoring Framework Guidelines, 2025 take effect **1 April 2026**: board-approved anti-fraud policy (red-flag indicators, investigation timelines), Fraud Monitoring Committee, independent fraud monitoring unit, annual comprehensive fraud risk assessment, FMR-1 annual return within 30 days of year end, participation in the IIB fraud-monitoring technology framework and its Caution Repository. Fraud categories include policyholder and claims fraud. | JSA Prism summary (Oct 2025) |
| IRDAI has no standalone AI rule for claims as far as found; AI-assisted claims fall under the 2024 Protection of Policyholders' Interests Regulations and Master Circular, and the insurer stays accountable for each decision. | vendor explainer, verify against regulation text |
| Existing tools such as HDFC ERGO's IDEAS focus on damage detection and cost estimation from photos, assisting surveyors. | Outlook Business (2020 article) |

Implication: AI-assisted assessment is normal for small claims, so "uses AI" is not a differentiator. Investigation of suspicious claims, with evidence and due process, is the gap this project targets.

## 15. Differentiation

Not unique claims. This is our focus and what we build deliberately differently.

| Differentiator | Generic approach | FraudGuard approach |
|---|---|---|
| Explainability | "Risk score 85%" | Evidence-anchored flags: document, page, bbox or policy field, benign explanations, next step |
| India fit | Language- and format-agnostic OCR/rules | Hindi/Marathi OCR, vehicle number and GSTIN validators, IPC vs BNS, break-in policies, garage patterns |
| Process | Score then decision | Verification-request loop with SLA clocks; the customer can respond before any verdict |
| Customer treatment | Opaque | Customers never see scores; neutral requests only; benign explanations shown to investigators |
| Evidence quality | Accept whatever is uploaded | Guided capture with blur checks, live-camera photos, EXIF/GPS |
| Regulatory shape | Generic dashboards | Red-flag library mapped to IRDAI 2025 categories, fraud register export, audit trail |
| Data honesty | Unstated | Open synthetic generator and evaluation harness, metrics labelled synthetic |

Stretch (design only, needs privacy review): hash-only cross-insurer duplicate-photo lookup modelled on the idea of the IIB's shared repository. Do not build before the core is done.

## 16. Evidence flag specification

```json
{
  "flagId": "F-102",
  "claimId": 101,
  "code": "FIR_VEHICLE_MISMATCH",
  "category": "DOCUMENT_INCONSISTENCY",
  "severity": "HIGH",
  "source": "document-service",
  "evidence": [
    { "type": "DOCUMENT", "claimDocId": 55, "page": 1, "bbox": [112, 340, 298, 366], "text": "MH12AB1243" },
    { "type": "POLICY", "field": "vehicleNumber", "value": "MH12AB1234" }
  ],
  "explanation": "Vehicle number in the FIR differs from the policy by one digit.",
  "benignExplanations": ["OCR misread", "Typing error at the police station"],
  "nextSteps": ["Request RC copy from the customer", "Confirm FIR number with the police station"],
  "confidence": 0.82,
  "status": "OPEN",
  "reviewedBy": null,
  "reviewReason": null
}
```

Rules:
- `severity`: `LOW | MEDIUM | HIGH`. `status`: `OPEN | CONFIRMED | DISMISSED | NEEDS_INFO`.
- `evidence` must contain at least one item; `benignExplanations` and `nextSteps` must be non-empty.
- `bbox` is `[x1, y1, x2, y2]` in PDF points or image pixels, with the page number.
- Flags are append-only. Re-running analysis creates new flags and supersedes old ones, it never edits history.
- Dismissed or confirmed flags with the investigator's reason are the labelled data for evaluation and retraining.

## 17. AI guardrails (for anyone writing code or prompts for this project)

1. Never write code that sets `claim_status` to `APPROVED`/`REJECTED` or `fraud_status` to `CONFIRMED` from an AI result.
2. Never expose `fraud_score`, flags, or `benignExplanations` through any customer endpoint or customer screen.
3. Never let an AI service connect to the main database or be called from the mobile app. Use `X-Internal-Key` and callbacks.
4. Every AI request and result carries `tenantId`; reject mismatches.
5. LLM output (case summaries) is advisory, must be generated from structured flags, must not add facts, and must be labelled "AI-generated".
6. All thresholds and rule weights live in configuration, with a version recorded on each result.
7. Failure of any AI call must degrade to `UNSCORED`, never block or fail claim filing.
8. Never invent accuracy numbers. State dataset, size, and that it is synthetic.
9. Do not store identifiers that checks do not need (Aadhaar, full licence numbers).

## 18. Revised success metrics (additions)

| Metric | Target | Measured |
|---|---|---|
| Flags with valid evidence reference | 100% (enforced by schema) | TODO |
| Investigator agreement with HIGH flags (confirmed / reviewed) on the synthetic set | TODO | TODO |
| False-positive rate on clean synthetic claims | TODO | TODO |
| Median investigator time per claim, with vs. without flags (small pilot or timed demo) | TODO | TODO |
| Verification requests resolved within due date | TODO | TODO |
