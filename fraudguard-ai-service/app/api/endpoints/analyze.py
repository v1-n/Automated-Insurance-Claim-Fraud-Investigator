"""
Full Claim Analysis Orchestration Endpoint: POST /api/v1/analyze-claim

Orchestrates complete claim fraud verification by analyzing uploaded documents
(FIR, Invoices, RC) with OCR, performing forensic inspection on accident photos
(EXIF metadata, GPS coordinates, and perceptual hashes), executing insurance
business rules, and producing an aggregated risk score and evidence flags.
"""

import asyncio
import logging
from datetime import date, datetime
from zoneinfo import ZoneInfo
from fastapi import APIRouter, Depends
import httpx

from app.enums.severity import Severity
from app.models.analyze_claim_request import AnalyzeClaimRequest
from app.models.analyze_claim_response import (
    AnalyzeClaimResponse,
    ClaimAnalysisDetails,
    ClaimEvidenceFlag,
    DocumentSummaryResult,
    PhotoHashResult,
    Recommendation,
    RiskLevel,
)

# Reuse existing document and photo inspection building blocks
from app.api.endpoints.documents import download_and_extract_text, cross_check_ground_truth
from app.api.endpoints.photos import inspect_photo
from app.models.photo_inspect_request import PhotoInspectRequest, IncidentPhotoContext
from app.utils.auth import verify_internal_key

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1")


def calculate_claim_risk_score(
    flags: list[ClaimEvidenceFlag],
    claim_amount: float,
    idv: float | None,
) -> tuple[int, RiskLevel, Recommendation]:
    """
    Computes a composite fraud risk score (0-100), risk level, and recommendation.

    Scoring formula:
      - HIGH severity flags: +35 points each
      - MEDIUM severity flags: +15 points each
      - LOW severity flags: +5 points each
      - Claim amount exceeding 80% of vehicle IDV: +15 points
      - Clamped between 0 and 100

    Thresholds:
      - Score >= 60 or >= 1 HIGH flag: HIGH Risk -> INVESTIGATE
      - Score >= 25 or >= 1 MEDIUM flag: MEDIUM Risk -> REVIEW
      - Otherwise: LOW Risk -> FAST_TRACK
    """
    score = 0
    high_count = sum(1 for f in flags if f.severity == Severity.HIGH)
    med_count = sum(1 for f in flags if f.severity == Severity.MEDIUM)
    low_count = sum(1 for f in flags if f.severity == Severity.LOW)

    score += high_count * 35
    score += med_count * 15
    score += low_count * 5

    # Check claim amount vs vehicle IDV
    if idv and idv > 0 and (claim_amount / idv) > 0.8:
        score += 15

    score = min(max(score, 0), 100)

    if score >= 60 or high_count >= 1:
        risk_level = RiskLevel.HIGH
        recommendation = Recommendation.INVESTIGATE
    elif score >= 25 or med_count >= 1:
        risk_level = RiskLevel.MEDIUM
        recommendation = Recommendation.REVIEW
    else:
        risk_level = RiskLevel.LOW
        recommendation = Recommendation.FAST_TRACK

    return score, risk_level, recommendation


@router.post("/analyze-claim", response_model=AnalyzeClaimResponse, dependencies=[Depends(verify_internal_key)])
async def analyze_claim(payload: AnalyzeClaimRequest):
    """
    Orchestrate full fraud analysis for a submitted insurance claim.

    Process:
      1. Downloads and extracts text from non-photo documents (PDFs, scans) using
         PyMuPDF and Tesseract OCR, validating vehicle registration numbers and legal codes.
      2. Performs forensic inspection on accident photos (perceptual hashing, camera EXIF,
         GPS distance verification, and cross-claim duplicate detection).
      3. Validates claim-level insurance constraints (policy validity period, vehicle IDV).
      4. Synthesizes all findings into a composite risk score (0-100) with explainable
         evidence flags adhering to IRDAI red-flag guidelines.
    """
    logger.info(
        f"[{payload.tenant_id}] Starting full claim analysis for Claim #{payload.claim_id} ({payload.claim_number})"
    )

    all_flags: list[ClaimEvidenceFlag] = []
    document_summaries: list[DocumentSummaryResult] = []
    photo_hashes: list[PhotoHashResult] = []
    flag_idx = 1

    async with httpx.AsyncClient() as client:
        # Document Verification (FIR, Invoice, Vehicle Documents)
        for doc in payload.documents:
            full_text, pages, extraction_failed = await download_and_extract_text(
                client=client,
                doc_id=doc.claim_doc_id,
                url=doc.document_url,
            )

            if extraction_failed:
                document_summaries.append(
                    DocumentSummaryResult(
                        claim_doc_id=doc.claim_doc_id,
                        document_type=str(doc.document_type),
                        vehicle_verified=False,
                        text_length=len(full_text),
                    )
                )
                all_flags.append(
                    ClaimEvidenceFlag(
                        flag_id=f"FLAG-{payload.claim_id}-{flag_idx:02d}",
                        code=f"{doc.document_type}_EXTRACTION_FAILED",
                        category="DOCUMENT_INCONSISTENCY",
                        severity=Severity.MEDIUM,
                        source="document-ocr",
                        explanation=f"Could not read or download {doc.document_type} (Doc #{doc.claim_doc_id}).",
                        benign_explanations=["Scanned image is low resolution or file was corrupted during upload"],
                        next_steps=["Request claimant to re-upload a clear copy of the document"],
                        confidence=0.90,
                    )
                )
                flag_idx += 1
            else:
                doc_flags = cross_check_ground_truth(
                    doc_type=str(doc.document_type),
                    doc_id=doc.claim_doc_id,
                    text=full_text,
                    ground_truth=payload.ground_truth,
                )

                has_vehicle_issue = any("VEHICLE" in df["code"] for df in doc_flags)
                document_summaries.append(
                    DocumentSummaryResult(
                        claim_doc_id=doc.claim_doc_id,
                        document_type=str(doc.document_type),
                        vehicle_verified=not has_vehicle_issue,
                        text_length=len(full_text),
                    )
                )

                for df in doc_flags:
                    all_flags.append(
                        ClaimEvidenceFlag(
                            flag_id=f"FLAG-{payload.claim_id}-{flag_idx:02d}",
                            code=df["code"],
                            category="DOCUMENT_INCONSISTENCY",
                            severity=df["severity"],
                            source="document-ocr",
                            explanation=df["explanation"],
                            benign_explanations=df.get("benignExplanations", []),
                            next_steps=df.get("nextSteps", []),
                            confidence=0.85,
                        )
                    )
                    flag_idx += 1

        # Photo Forensics (EXIF Metadata, Tampering, GPS, Cross-Claim Duplicates)
        incident_context = IncidentPhotoContext(
            incident_date=payload.ground_truth.incident_date,
            incident_city=payload.ground_truth.incident_city,
            incident_state=payload.ground_truth.incident_state,
            incident_latitude=payload.ground_truth.incident_latitude,
            incident_longitude=payload.ground_truth.incident_longitude,
        )

        for photo in payload.photos:
            photo_req = PhotoInspectRequest(
                tenant_id=str(payload.tenant_id),
                claim_id=payload.claim_id,
                photo_id=photo.claim_doc_id,
                photo_url=photo.photo_url,
                incident_context=incident_context,
                existing_hashes=photo.existing_hashes,
            )

            try:
                photo_res = await inspect_photo(photo_req)
            except Exception as e:
                logger.error(
                    f"[Photo #{photo.claim_doc_id}] Failed to download/inspect photo: {e}",
                    exc_info=True,
                )
                all_flags.append(
                    ClaimEvidenceFlag(
                        flag_id=f"FLAG-{payload.claim_id}-{flag_idx:02d}",
                        code="PHOTO_DOWNLOAD_FAILED",
                        category="PHOTO_FORENSICS",
                        severity=Severity.MEDIUM,
                        source="photo-forensics",
                        explanation=f"Could not download or inspect photo (Doc #{photo.claim_doc_id}): {str(e)}",
                        benign_explanations=["Temporary network issue or invalid image URL"],
                        next_steps=["Request claimant to re-upload photo"],
                        confidence=0.90,
                    )
                )
                flag_idx += 1
                continue
            photo_hashes.append(
                PhotoHashResult(claim_doc_id=photo.claim_doc_id, phash=photo_res.phash)
            )

            for pf in photo_res.flags:
                all_flags.append(
                    ClaimEvidenceFlag(
                        flag_id=f"FLAG-{payload.claim_id}-{flag_idx:02d}",
                        code=pf.code,
                        category="PHOTO_FORENSICS",
                        severity=pf.severity,
                        source="photo-forensics",
                        explanation=pf.explanation,
                        benign_explanations=pf.benignExplanations,
                        next_steps=pf.nextSteps,
                        confidence=0.90,
                    )
                )
                flag_idx += 1

    # Claim-Level Business Rules (Policy Validity & Insured Declared Value)
    gt = payload.ground_truth

    # Rule: Incident date must fall within the active policy coverage period
    if gt.policy_start_date and gt.policy_end_date:
        p_start = gt.policy_start_date.date() if hasattr(gt.policy_start_date, "date") else gt.policy_start_date
        p_end = gt.policy_end_date.date() if hasattr(gt.policy_end_date, "date") else gt.policy_end_date
        inc_date = gt.incident_date.date() if hasattr(gt.incident_date, "date") else gt.incident_date

        if inc_date < p_start or inc_date > p_end:
            all_flags.append(
                ClaimEvidenceFlag(
                    flag_id=f"FLAG-{payload.claim_id}-{flag_idx:02d}",
                    code="CLAIM_INCIDENT_OUTSIDE_POLICY_PERIOD",
                    category="CLAIM_RULES",
                    severity=Severity.HIGH,
                    source="claim-rules",
                    explanation=f"Incident date ({inc_date}) is outside active policy dates ({p_start} to {p_end}).",
                    benign_explanations=["Claimant misremembered incident date or policy renewal date"],
                    next_steps=["Verify insurance policy certificate and endorse correct timeline"],
                    confidence=0.99,
                )
            )
            flag_idx += 1

    # Rule: Claim amount should not exceed the vehicle's Insured Declared Value (IDV)
    if gt.idv_amount and payload.claim_amount > gt.idv_amount:
        all_flags.append(
            ClaimEvidenceFlag(
                flag_id=f"FLAG-{payload.claim_id}-{flag_idx:02d}",
                code="CLAIM_EXCEEDS_IDV",
                category="CLAIM_RULES",
                severity=Severity.MEDIUM,
                source="claim-rules",
                explanation=f"Claim amount (₹{payload.claim_amount:,.2f}) exceeds total vehicle IDV (₹{gt.idv_amount:,.2f}).",
                benign_explanations=["Constructive total loss case requiring salvage valuation"],
                next_steps=["Order physical inspection and evaluate scrap salvage value"],
                confidence=0.95,
            )
        )
        flag_idx += 1

    # Rule: Incident date sanity checks (using IST to avoid false positives near midnight)
    ist = ZoneInfo("Asia/Kolkata")
    today_ist = datetime.now(ist).date()
    inc_date_for_sanity = gt.incident_date.date() if hasattr(gt.incident_date, "date") and callable(gt.incident_date.date) else gt.incident_date

    if inc_date_for_sanity > today_ist:
        all_flags.append(
            ClaimEvidenceFlag(
                flag_id=f"FLAG-{payload.claim_id}-{flag_idx:02d}",
                code="INCIDENT_DATE_IN_FUTURE",
                category="CLAIM_RULES",
                severity=Severity.HIGH,
                source="claim-rules",
                explanation=(
                    f"Claimed incident date ({inc_date_for_sanity}) is in the future "
                    f"(today IST: {today_ist}). An incident cannot occur ahead of current date."
                ),
                benign_explanations=["Date entry error during claim registration"],
                next_steps=["Verify original policyholder claim form and re-enter correct date"],
                confidence=0.99,
            )
        )
        flag_idx += 1
    elif (today_ist - inc_date_for_sanity).days > 365:
        days_ago = (today_ist - inc_date_for_sanity).days
        all_flags.append(
            ClaimEvidenceFlag(
                flag_id=f"FLAG-{payload.claim_id}-{flag_idx:02d}",
                code="INCIDENT_DATE_SEVERELY_DELAYED",
                category="CLAIM_RULES",
                severity=Severity.MEDIUM,
                source="claim-rules",
                explanation=(
                    f"Claimed incident date ({inc_date_for_sanity}) is {days_ago} days old (>1 year). "
                    "Claim filed with excessive delay."
                ),
                benign_explanations=["Legal dispute or delayed third-party claim settlement"],
                next_steps=["Request explanation and police/court records for reporting delay"],
                confidence=0.90,
            )
        )
        flag_idx += 1

    # Composite Risk Scoring & Recommendation
    risk_score, risk_level, recommendation = calculate_claim_risk_score(
        flags=all_flags,
        claim_amount=payload.claim_amount,
        idv=gt.idv_amount,
    )

    if recommendation == Recommendation.INVESTIGATE:
        summary = (
            f"High Risk (Score {risk_score}/100): Claim flagged with {len(all_flags)} issues. "
            "Investigation recommended before approval."
        )
    elif recommendation == Recommendation.REVIEW:
        summary = (
            f"Medium Risk (Score {risk_score}/100): Claim contains minor discrepancies or "
            "missing EXIF metadata requiring desktop review."
        )
    else:
        summary = f"Low Risk (Score {risk_score}/100): All checks verified cleanly. Fast-track eligible."

    logger.info(
        f"[{payload.tenant_id}] Completed claim analysis for Claim #{payload.claim_id}: "
        f"Score={risk_score}, Recommendation={recommendation}, Total Flags={len(all_flags)}"
    )

    return AnalyzeClaimResponse(
        claim_id=payload.claim_id,
        tenant_id=payload.tenant_id,
        risk_score=risk_score,
        risk_level=risk_level,
        recommendation=recommendation,
        summary=summary,
        flags=all_flags,
        details=ClaimAnalysisDetails(
            total_documents_analyzed=len(payload.documents),
            total_photos_analyzed=len(payload.photos),
            document_summaries=document_summaries,
            photo_hashes=photo_hashes,
        ),
    )
