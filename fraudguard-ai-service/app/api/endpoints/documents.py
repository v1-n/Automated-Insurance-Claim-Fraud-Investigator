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

# Initialize logger for this module
logger = logging.getLogger(__name__)

router = APIRouter()


async def download_and_extract_text(client:httpx.AsyncClient,doc_id:int,url:str)->tuple[str,list[dict]]:
    try:
        res=await client.get(url)
        res.raise_for_status()
        raw_file=res.content
        logger.info(f"[Doc #{doc_id}] Download complete ({len(raw_file)} bytes)")
    except httpx.HTTPStatusError as e:
        logger.error(f"[Doc #{doc_id}] HTTP error downloading document: {e.response.status_code}")
        return f"[DOWNLOAD_FAILED: HTTP {e.response.status_code}]", []
    except Exception as e:
        logger.error(f"[Doc #{doc_id}] Network error: {str(e)}", exc_info=True)
        return f"[DOWNLOAD_FAILED: {str(e)}]", []

    # Detect file type
    content_type = res.headers.get("content-type", "").lower()
    if raw_file.startswith(b"%PDF") or "pdf" in content_type:
        file_ext = "pdf"
    elif "image/png" in content_type or url.lower().endswith(".png"):
        file_ext = "png"
    else:
        file_ext = "jpg"

    try:
        doc = pymupdf.open(stream=raw_file, filetype=file_ext)
    except Exception as e:
        logger.error(f"[Doc #{doc_id}] Failed to parse file with PyMuPDF: {str(e)}")
        return f"[CORRUPTED_DOCUMENT: {str(e)}]", []

    if len(doc) == 0:
        logger.warning(f"[Doc #{doc_id}] Document opened but contains 0 pages")
        doc.close()
        return "", []

    extracted_pages=[]

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
        else:
            logger.debug(f"[Doc #{doc_id} | Page {page_num}] Extracted digital text ({len(page_text)} chars)")


        extracted_pages.append({
            "page":page_num,
             "text":page_text
             })

    doc.close()
    full_text="\n".join(p["text"]for p in extracted_pages)
    return full_text,extracted_pages


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
                "severity": "HIGH",
                "document_id": doc_id,
                "explanation": f"Vehicle number '{ground_truth.vehicle_number}' was not found in the {doc_type}."
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
                    "severity": "MEDIUM",
                    "document_id": doc_id,
                    "explanation": "Incident is on/after 1 July 2024, but FIR cites IPC instead of BNS."
                })
    return flags


@router.post("/verify-document")
async def verify_documents(payload: DocumentVerifyRequest):
    logger.info(f"[{payload.tenant_id}] Received verification request for Claim #{payload.claim_id} with {len(payload.documents)} document(s)")

    flags = []
    extracted_docs = []

    async with httpx.AsyncClient() as client:
        for doc in payload.documents:
            full_text,pages= await download_and_extract_text(client,doc.document_id,doc.document_url)

            # Cross-check rules
            doc_flags = cross_check_ground_truth(doc.document_type, doc.document_id, full_text, payload.ground_truth)
            flags.extend(doc_flags)
            extracted_docs.append({
                "document_id": doc.document_id,
                "document_type": doc.document_type,
                "text_length": len(full_text)
            })

    status = "SUSPICIOUS" if any(f.get("severity") == "HIGH" for f in flags) else "PASSED"
    logger.info(
        f"[{payload.tenant_id}] Finished Claim #{payload.claim_id} analysis: Status={status}, Generated Flags={len(flags)}")
    return {
        "claim_id": payload.claim_id,
        "verification_status": status,
        "total_documents_analyzed": len(payload.documents),
        "flags": flags,
        "summary": f"Analyzed {len(payload.documents)} document(s). Generated {len(flags)} flag(s)."
    }