import asyncio
from difflib import SequenceMatcher
import logging
import re
from datetime import datetime
import httpx
import pymupdf
from fastapi import APIRouter
from app.models.document_verify_request import DocumentVerifyRequest
from app.models.document_verify_response import DocumentVerifyResponse
from app.enums.severity import Severity
from app.enums.verification_status import VerificationStatus
from app.utils.file_downloader import download_file

logger = logging.getLogger(__name__)

router = APIRouter()


async def download_and_extract_text(
    client: httpx.AsyncClient, doc_id: int, url: str
) -> tuple[str, list[dict], str | None]:
    """
    Downloads and extracts text from a document.
    Returns: (full_text, pages, error_type)
    error_type is:
      - None: successful extraction
      - 'DOWNLOAD_FAILED': network error or HTTP non-200 (eligible for retry)
      - 'EXTRACTION_FAILED': corrupted file, empty document, or OCR unreadable
    """
    try:
        downloaded = await download_file(url, item_tag=f"Doc #{doc_id}", client=client)
    except httpx.HTTPStatusError as e:
        logger.error(f"[Doc #{doc_id}] HTTP error downloading document: {e.response.status_code}")
        return f"[DOWNLOAD_FAILED: HTTP {e.response.status_code}]", [], "DOWNLOAD_FAILED"
    except Exception as e:
        logger.error(f"[Doc #{doc_id}] Network error: {str(e)}", exc_info=True)
        return f"[DOWNLOAD_FAILED: {str(e)}]", [], "DOWNLOAD_FAILED"

    try:
        doc = pymupdf.open(stream=downloaded.content, filetype=downloaded.file_ext)
    except Exception as e:
        logger.error(f"[Doc #{doc_id}] Failed to parse file with PyMuPDF: {str(e)}")
        return f"[CORRUPTED_DOCUMENT: {str(e)}]", [], "EXTRACTION_FAILED"

    if len(doc) == 0:
        logger.warning(f"[Doc #{doc_id}] Document opened but contains 0 pages")
        doc.close()
        return "", [], "EXTRACTION_FAILED"

    extracted_pages = []
    ocr_failed = False

    for page_num, page in enumerate(doc, start=1):
        page_text = page.get_text()

        if not page_text.strip():
            logger.warning(f"[Doc #{doc_id} | Page {page_num}] No digital text found; invoking Tesseract OCR...")

            try:
                ocr_page = await asyncio.to_thread(
                    page.get_textpage_ocr, language="eng", dpi=300, full=True
                )
                page_text = page.get_text(textpage=ocr_page)
                logger.info(f"[Doc #{doc_id} | Page {page_num}] OCR extraction completed ({len(page_text)} chars)")
            except Exception as e:
                logger.error(f"[Doc #{doc_id} | Page {page_num}] Tesseract OCR failed: {str(e)}")
                page_text = ""
                ocr_failed = True
        else:
            logger.debug(f"[Doc #{doc_id} | Page {page_num}] Extracted digital text ({len(page_text)} chars)")

        extracted_pages.append({
            "page": page_num,
            "text": page_text,
        })

    doc.close()
    full_text = "\n".join(p["text"] for p in extracted_pages)

    if ocr_failed and not full_text.strip():
        return full_text, extracted_pages, "EXTRACTION_FAILED"

    return full_text, extracted_pages, None


def _normalize_ocr_characters(s: str) -> str:
    """Replaces visually similar characters commonly confused by OCR in registration plates."""
    table = str.maketrans({
        'O': '0',
        'I': '1',
        'L': '1',
        'Z': '2',
        'S': '5',
        'B': '8',
    })
    return s.translate(table)


def evaluate_vehicle_registration(doc_type: str, doc_id: int, text: str, vehicle_number: str | None) -> list[dict]:
    """
    Evaluates vehicle registration with a 4-state matcher:
      1. MATCH: Exact substring or OCR-normalized match (O/0, I/1, etc.) -> No flag
      2. NEAR: High similarity substring (>= 0.78) -> LOW severity advisory flag
      3. MISMATCH: Document contains a different vehicle registration plate -> HIGH severity
      4. NOT_FOUND: Vehicle number absent from document -> HIGH severity
    """
    flags = []
    clean_text = text.upper().replace(" ", "").replace("-", "")
    target_vehicle = (vehicle_number or "").upper().replace(" ", "").replace("-", "").strip()

    if not target_vehicle:
        logger.warning(f"[Doc #{doc_id}] FLAG RAISED: Empty vehicle number in ground truth for {doc_type}")
        return [{
            "code": "POLICY_VEHICLE_NUMBER_MISSING",
            "severity": Severity.HIGH,
            "document_id": doc_id,
            "explanation": f"Vehicle registration number is empty or blank in claim ground truth. Cannot verify vehicle in {doc_type}.",
            "benignExplanations": ["Claimant or agent submitted claim without entering vehicle registration number"],
            "nextSteps": ["Request vehicle registration certificate (RC) and update claim details"]
        }]

    if len(target_vehicle) < 6:
        logger.warning(f"[Doc #{doc_id}] FLAG RAISED: Invalid short vehicle number '{vehicle_number}' in ground truth")
        return [{
            "code": "INVALID_VEHICLE_REGISTRATION_NUMBER",
            "severity": Severity.HIGH,
            "document_id": doc_id,
            "explanation": (
                f"Vehicle number '{vehicle_number}' is invalid or too short (< 6 characters). "
                "Valid Indian vehicle registrations include state code, district, and unique digits (e.g., MH12AB1234)."
            ),
            "benignExplanations": ["User entered placeholder text during testing or form entry"],
            "nextSteps": ["Request official RC smartcard or vehicle insurance certificate copy"]
        }]

    # 1. EXACT SUBSTRING MATCH (No flags, 100% clean)
    if target_vehicle in clean_text:
        logger.info(f"[Doc #{doc_id}] Vehicle number '{vehicle_number}' matched exactly in {doc_type}")
        return []

    # 2. OCR NORMALIZED CHARACTER MATCH (O/0, I/1, S/5, B/8, Z/2, L/1 substitution)
    # Emit a LOW severity NEAR flag so investigators see the OCR correction
    if _normalize_ocr_characters(target_vehicle) in _normalize_ocr_characters(clean_text):
        logger.info(f"[Doc #{doc_id}] Vehicle number '{vehicle_number}' matched via OCR normalization in {doc_type}")
        return [{
            "code": f"{doc_type}_VEHICLE_NEAR_MATCH",
            "severity": Severity.LOW,
            "document_id": doc_id,
            "explanation": (
                f"Vehicle registration in {doc_type} matches ground truth with character substitution "
                f"(e.g. O/0, I/1, S/5, B/8, Z/2). Likely OCR distortion of '{vehicle_number}'."
            ),
            "benignExplanations": ["Font or stamp noise on physical document caused character substitution in OCR"],
            "nextSteps": ["Verify original document image to confirm plate number"]
        }]

    # 3. SCAN FOR CANDIDATE PLATE TOKENS (Strictly alphanumeric with letters AND digits)
    plate_regex = re.compile(r'[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{4}')
    detected_plates = plate_regex.findall(clean_text)

    # Find words/tokens containing both letters and digits within length bounds (prevents false matches on prose)
    t_len = len(target_vehicle)
    alphanumeric_tokens = re.findall(r'[A-Z0-9]{6,12}', clean_text)
    candidate_tokens = set(detected_plates)
    for token in alphanumeric_tokens:
        if abs(len(token) - t_len) <= 2 and any(c.isalpha() for c in token) and any(c.isdigit() for c in token):
            candidate_tokens.add(token)

    best_ratio = 0.0
    best_candidate = ""
    for token in candidate_tokens:
        ratio = SequenceMatcher(None, target_vehicle, token).ratio()
        if ratio > best_ratio:
            best_ratio = ratio
            best_candidate = token

    # 4. NEAR MATCH (Similarity >= 0.82 on valid plate candidate)
    if best_ratio >= 0.82:
        logger.info(
            f"[Doc #{doc_id}] Vehicle near match in {doc_type}: target '{target_vehicle}' vs detected '{best_candidate}' ({best_ratio*100:.0f}%)"
        )
        flags.append({
            "code": f"{doc_type}_VEHICLE_NEAR_MATCH",
            "severity": Severity.LOW,
            "document_id": doc_id,
            "explanation": (
                f"Vehicle registration in {doc_type} closely matches ground truth "
                f"('{vehicle_number}' vs detected '{best_candidate}', {best_ratio*100:.0f}% similarity). "
                "Minor variance is consistent with OCR character distortion."
            ),
            "benignExplanations": ["OCR misread a visually similar character on the printed number plate"],
            "nextSteps": ["Review original document scan to verify registration characters"]
        })
        return flags

    # 4. CONFLICTING PLATE FOUND -> MISMATCH
    conflicting_plates = [p for p in detected_plates if SequenceMatcher(None, target_vehicle, p).ratio() < 0.6]
    if conflicting_plates:
        conflicting = conflicting_plates[0]
        logger.warning(
            f"[Doc #{doc_id}] FLAG RAISED: Vehicle mismatch! Found conflicting plate '{conflicting}' in {doc_type}"
        )
        flags.append({
            "code": f"{doc_type}_VEHICLE_MISMATCH",
            "severity": Severity.HIGH,
            "document_id": doc_id,
            "explanation": (
                f"Document {doc_type} specifies a different vehicle registration ('{conflicting}') "
                f"than claimed vehicle '{vehicle_number}'."
            ),
            "benignExplanations": ["Accident report involves a third-party or opposite vehicle"],
            "nextSteps": ["Check if cited vehicle belongs to the other involved party or claimant"]
        })
        return flags

    # 5. NOT FOUND
    logger.warning(
        f"[Doc #{doc_id}] FLAG RAISED: Vehicle number '{vehicle_number}' not found in {doc_type}"
    )
    flags.append({
        "code": f"{doc_type}_VEHICLE_NOT_FOUND",
        "severity": Severity.HIGH,
        "document_id": doc_id,
        "explanation": f"Vehicle registration number '{vehicle_number}' could not be located in {doc_type}.",
        "benignExplanations": ["Low-contrast scan or folded document obscured the vehicle number section"],
        "nextSteps": ["Request clean high-resolution scan or inspect physical document"]
    })
    return flags


def cross_check_ground_truth(doc_type: str, doc_id: int, text: str, ground_truth) -> list[dict]:
    flags = []

    # Vehicle Registration Check
    if doc_type in ["FIR", "VEHICLE_DOCUMENT", "INVOICE"]:
        vehicle_flags = evaluate_vehicle_registration(
            doc_type=doc_type,
            doc_id=doc_id,
            text=text,
            vehicle_number=ground_truth.vehicle_number,
        )
        flags.extend(vehicle_flags)

    # Legal Code Check (BNS vs. IPC)
    if doc_type == "FIR":
        cutoff_date = datetime(2024, 7, 1).date()
        incident_date = (
            ground_truth.incident_date.date()
            if hasattr(ground_truth.incident_date, "date") and callable(ground_truth.incident_date.date)
            else ground_truth.incident_date
        )
        if incident_date and incident_date >= cutoff_date:
            if "IPC" in text.upper() and "BNS" not in text.upper():
                logger.warning(f"[Doc #{doc_id}] FLAG RAISED: Obsolete legal code (IPC cited for post-July-2024 incident)")
                flags.append({
                    "code": "FIR_OBSOLETE_LEGAL_CODE",
                    "severity": Severity.MEDIUM,
                    "document_id": doc_id,
                    "explanation": "Incident is on/after 1 July 2024, but FIR cites IPC instead of BNS.",
                    "benignExplanations": ["Police station used older FIR template software"],
                    "nextSteps": ["Verify FIR authenticity with the registered police station"]
                })
    return flags


@router.post("/verify-document", response_model=DocumentVerifyResponse)
async def verify_documents(payload: DocumentVerifyRequest):
    logger.info(
        f"[{payload.tenant_id}] Received verification request for Claim #{payload.claim_id} with {len(payload.documents)} document(s)"
    )

    flags = []
    extracted_docs = []
    has_critical_failure = False

    async with httpx.AsyncClient() as client:
        for doc in payload.documents:
            full_text, pages, error_type = await download_and_extract_text(client, doc.document_id, doc.document_url)

            if error_type == "DOWNLOAD_FAILED":
                has_critical_failure = True
                flags.append({
                    "code": f"{doc.document_type}_DOWNLOAD_FAILED",
                    "severity": Severity.MEDIUM,
                    "document_id": doc.document_id,
                    "explanation": f"Network or server error while downloading {doc.document_type} (Doc #{doc.document_id}).",
                    "benignExplanations": ["Temporary network timeout or invalid URL"],
                    "nextSteps": ["Retry document download or request claimant to re-upload"]
                })
            elif error_type == "EXTRACTION_FAILED":
                has_critical_failure = True
                flags.append({
                    "code": f"{doc.document_type}_EXTRACTION_FAILED",
                    "severity": Severity.MEDIUM,
                    "document_id": doc.document_id,
                    "explanation": f"Could not extract legible text from {doc.document_type} (Doc #{doc.document_id}).",
                    "benignExplanations": ["Low-resolution scan or corrupted file"],
                    "nextSteps": ["Request a higher-resolution scan or inspect physical document"]
                })
            else:
                doc_flags = cross_check_ground_truth(doc.document_type, doc.document_id, full_text, payload.ground_truth)
                flags.extend(doc_flags)

            extracted_docs.append({
                "document_id": doc.document_id,
                "document_type": str(doc.document_type),
                "text_length": len(full_text),
                "extraction_failed": bool(error_type),
            })

    if has_critical_failure:
        status = VerificationStatus.FAILED
    elif any(f.get("severity") == Severity.HIGH for f in flags):
        status = VerificationStatus.SUSPICIOUS
    else:
        status = VerificationStatus.PASSED

    logger.info(
        f"[{payload.tenant_id}] Finished Claim #{payload.claim_id} analysis: Status={status}, Generated Flags={len(flags)}"
    )
    return DocumentVerifyResponse(
        claim_id=payload.claim_id,
        verification_status=status,
        total_documents_analyzed=len(payload.documents),
        extracted_documents=extracted_docs,
        flags=flags,
        summary=f"Analyzed {len(payload.documents)} document(s). Generated {len(flags)} flag(s)."
    )