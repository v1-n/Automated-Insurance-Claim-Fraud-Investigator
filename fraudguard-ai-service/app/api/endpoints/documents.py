# 1. Download documents from payload.documents using httpx
# 2. Run OCR (PyMuPDF for digital PDF, Tesseract for scans)
# 3. Cross-check against payload.ground_truth (Vehicle number, GSTIN, BNS vs IPC, Dates)
# 4. Return DocumentVerifyResponse

from fastapi import APIRouter
from app.models.document_verify_request import DocumentVerifyRequest
import httpx
import pymupdf
from websockets import client

router = APIRouter()


async def download_and_extract_text(client:httpx.AsyncClient,url:str)->tuple[str,list[dict]]:
    try:
        res=await client.get(url)
        res.raise_for_status()
        raw_file=res.content
    except Exception as e:
        return f"[DOWNLOAD_FAILED: {str(e)}]", []

    # Detect file type
    content_type = res.headers.get('content-type',"").lower()
    if raw_file.startswith(b"%PDF") or "pdf" in content_type:
        file_ext = "pdf"
    elif "image/png" in content_type or url.lower().endswith(".png"):
        file_ext="png"
    else:
        file_ext = "jpg"

    try:
        doc=pymupdf.open(stream=raw_file, filetype=file_ext)
    except Exception as e:
        return f"[CORRUPTED_DOCUMENT: {str(e)}]",[]

    if len(doc)==0:
        doc.close()
        return "",[]

    extracted_pages=[]

    for page_num,page in enumerate(doc,start=1):
        page_text=page.get_text()

        if not page_text.strip():
            try:
                ocr_page =page.get_textpage_ocr(language='eng', full=True)
                page_text=page.get_text(textpage=ocr_page)
            except Exception:
                page_text=""
        extracted_pages.append({
            "page":page_num,
             "text":page_text
             })

    doc.close()
    full_text="\n".join(p["text"]for p in extracted_pages)
    return full_text,extracted_pages

@router.post("/verify-document")
async def verify_documents(payload: DocumentVerifyRequest):
    all_extracted_texts = []
    async with httpx.AsyncClient() as client:
        for doc in payload.documents:
            full_text,pages= await download_and_extract_text(client,doc.document_url)
            print("full text ",full_text)
            print("\n pages",pages)
    return {
        "status": "success",
        "message": f"Successfully downloaded and processed {len(payload.documents)} document(s).",
        "text": full_text,
        "pages":pages
    }
