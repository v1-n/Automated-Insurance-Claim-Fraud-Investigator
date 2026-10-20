# 1. Download documents from payload.documents using httpx
# 2. Run OCR (PyMuPDF for digital PDF, Tesseract for scans)
# 3. Cross-check against payload.ground_truth (Vehicle number, GSTIN, BNS vs IPC, Dates)
# 4. Return DocumentVerifyResponse

import logging
import httpx
import pymupdf
from datetime import datetime
from fastapi import APIRouter
from app.models.document_verify_request import DocumentVerifyRequest
from app.models.document_verify_response import DocumentVerifyResponse
from app.enums.severity import Severity
from app.enums.verification_status import VerificationStatus

from app.utils.file_downloader import download_file

# Initialize logger for this module
logger = logging.getLogger(__name__)

router = APIRouter()


async def download_and_extract_text(client: httpx.AsyncClient, doc_id: int, url: str) -> tuple[str, list[dict], bool]:
    """Returns (full_text, pages, extraction_failed)."""
    try:
        downloaded = await download_file(url, item_tag=f"Doc #{doc_id}", client=client)
    except httpx.HTTPStatusError as e:
        logger.error(f"[Doc #{doc_id}] HTTP error downloading document: {e.response.status_code}")
        return f"[DOWNLOAD_FAILED: HTTP {e.response.status_code}]", [], True
    except Exception as e:
        logger.error(f"[Doc #{doc_id}] Network error: {str(e)}", exc_info=True)
        return f"[DOWNLOAD_FAILED: {str(e)}]", [], True

    try:
        doc = pymupdf.open(stream=downloaded.content, filetype=downloaded.file_ext)
    except Exception as e:
        logger.error(f"[Doc #{doc_id}] Failed to parse file with PyMuPDF: {str(e)}")
        return f"[CORRUPTED_DOCUMENT: {str(e)}]", [], True

    if len(doc) == 0:
        logger.warning(f"[Doc #{doc_id}] Document opened but contains 0 pages")
        doc.close()
        return "", [], True

    extracted_pages=[]
    ocr_failed = False

    for page_num,page in enumerate(doc,start=1):
        page_text=page.get_text()

        if not page_text.strip():
            logger.warning(f"[Doc #{doc_id} | Page {page_num}] No digital text found; invoking Tesseract OCR...")

            try:
                ocr_page = page.get_textpage_ocr(language="eng", dpi=300, full=True)
                page_text = page.get_text(textpage=ocr_page)
                logger.info(f"[Doc #{doc_id} | Page {page_num}] OCR extraction completed ({len(page_text)} chars)")
            except Exception as e:
                logger.error(f"[Doc #{doc_id} | Page {page_num}] Tesseract OCR failed: {str(e)}")
                page_text = ""
                ocr_failed = True
        else:
            logger.debug(f"[Doc #{doc_id} | Page {page_num}] Extracted digital text ({len(page_text)} chars)")


        extracted_pages.append({
            "page":page_num,
             "text":page_text
             })

    doc.close()
    full_text="\n".join(p["text"]for p in extracted_pages)

    # If OCR failed AND we got no usable text, mark as failed
    extraction_failed = ocr_failed and not full_text.strip()
    return full_text, extracted_pages, extraction_failed


def cross_check_ground_truth(doc_type: str, doc_id: int, text: str, ground_truth) -> list[dict]:
    flags = []
    clean_text = text.upper().replace(" ", "").replace("-", "")
    target_vehicle = ground_truth.vehicle_number.upper().replace(" ", "").replace("-", "")
    #  Vehicle Registration Check
    if doc_type in ["FIR", "VEHICLE_DOCUMENT", "INVOICE"]:
        if target_vehicle not in clean_text:
            logger.warning(f"[Doc #{doc_id}] FLAG RAISED: Vehicle mismatch! Ground truth '{ground_truth.vehicle_number}' missing in {doc_type}")
            flags.append({
                "code": f"{doc_type}_VEHICLE_MISMATCH",
                "severity": Severity.HIGH,
                "document_id": doc_id,
                "explanation": f"Vehicle number '{ground_truth.vehicle_number}' was not found in the {doc_type}.",
                "benignExplanations": ["Blurry scan or OCR misread digits", "Typing error in police station report"],
                "nextSteps": ["Request clean high-resolution scan", "Inspect physical document manual copy"]
            })
        else:
            logger.info(f"[Doc #{doc_id}] Vehicle number '{ground_truth.vehicle_number}' verified successfully in {doc_type}")
    #  Legal Code Check (BNS vs. IPC)
    if doc_type == "FIR":
        cutoff_date = datetime(2024, 7, 1).date()
        incident_date = ground_truth.incident_date if isinstance(ground_truth.incident_date, datetime) else ground_truth.incident_date
        if isinstance(incident_date, datetime):
            incident_date = incident_date.date()
        if incident_date >= cutoff_date:
            if "IPC" in text.upper() and "BNS" not in text.upper():
                logger.warning(f"[Doc #{doc_id}] FLAG RAISED: Obsolete legal code (IPC cited for post-July-2024 incident)")
                flags.append({
                    "code": "FIR_OBSOLETE_LEGAL_CODE",
                    "severity": Severity.MEDIUM,
                    "document_id": doc_id,
                    "explanation": "Incident is on/after 1 July 2024, but FIR cites IPC instead of BNS.",
                    "benignExplanations": ["Station used older FIR template software"],
                    "nextSteps": ["Verify FIR authenticity with the registered police station"]
                })
    return flags


@router.post("/verify-document", response_model=DocumentVerifyResponse)
async def verify_documents(payload: DocumentVerifyRequest):
    logger.info(f"[{payload.tenant_id}] Received verification request for Claim #{payload.claim_id} with {len(payload.documents)} document(s)")

    flags = []
    extracted_docs = []
    any_extraction_failed = False

    async with httpx.AsyncClient() as client:
        for doc in payload.documents:
            full_text, pages, extraction_failed = await download_and_extract_text(client, doc.document_id, doc.document_url)

            if extraction_failed:
                any_extraction_failed = True
                flags.append({
                    "code": f"{doc.document_type}_EXTRACTION_FAILED",
                    "severity": Severity.HIGH,
                    "document_id": doc.document_id,
                    "explanation": f"Failed to download or extract text from {doc.document_type} (Doc #{doc.document_id}). Document could not be verified.",
                    "benignExplanations": ["Document may be a scanned image requiring manual review", "Temporary network issue during download"],
                    "nextSteps": ["Request claimant to re-upload a clear, high-resolution copy", "Manually inspect the original document"]
                })
            else:
                # Cross-check rules only if extraction succeeded
                doc_flags = cross_check_ground_truth(doc.document_type, doc.document_id, full_text, payload.ground_truth)
                flags.extend(doc_flags)

            extracted_docs.append({
                "document_id": doc.document_id,
                "document_type": str(doc.document_type),
                "text_length": len(full_text),
                "extraction_failed": extraction_failed,
            })

    if any_extraction_failed:
        status = VerificationStatus.FAILED
    elif any(f.get("severity") == Severity.HIGH for f in flags):
        status = VerificationStatus.SUSPICIOUS
    else:
        status = VerificationStatus.PASSED

    logger.info(
        f"[{payload.tenant_id}] Finished Claim #{payload.claim_id} analysis: Status={status}, Generated Flags={len(flags)}")
    return DocumentVerifyResponse(
        claim_id=payload.claim_id,
        verification_status=status,
        total_documents_analyzed=len(payload.documents),
        extracted_documents=extracted_docs,
        flags=flags,
        summary=f"Analyzed {len(payload.documents)} document(s). Generated {len(flags)} flag(s)."
    )