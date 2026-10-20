import re
from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, Field, field_validator
from app.enums.document_type import DocumentType


class ClaimGroundTruth(BaseModel):
    vehicle_number: str = Field(..., description="Registered vehicle number from policy (e.g. MH12AB1234)")
    policy_number: Optional[str] = Field(None, description="Policy number associated with the claim")
    policy_start_date: Optional[date | datetime] = Field(None, description="Policy coverage start date")
    policy_end_date: Optional[date | datetime] = Field(None, description="Policy coverage expiry date")
    idv_amount: Optional[float] = Field(None, description="Insured Declared Value (IDV) of the vehicle")
    incident_date: date | datetime = Field(..., description="Claimed date and time of the accident")
    incident_city: str = Field(..., description="City where the accident occurred (e.g. Pune)")
    incident_state: Optional[str] = Field(None, description="State of the accident location")
    incident_latitude: Optional[float] = Field(None, description="Optional incident GPS latitude")
    incident_longitude: Optional[float] = Field(None, description="Optional incident GPS longitude")

    @field_validator("incident_date", "policy_start_date", "policy_end_date", mode="before")
    @classmethod
    def parse_flexible_dates(cls, v):
        if not v or isinstance(v, (date, datetime)):
            return v
        if isinstance(v, str):
            v_clean = v.strip()
            try:
                return datetime.fromisoformat(v_clean)
            except ValueError:
                m = re.match(r"^(\d{4})-(\d{1,2})-(\d{1,2})(?:[T ](\d{1,2}):(\d{2})(?::(\d{2}))?)?", v_clean)
                if m:
                    year, month, day = int(m.group(1)), int(m.group(2)), int(m.group(3))
                    hour = int(m.group(4)) if m.group(4) else 0
                    minute = int(m.group(5)) if m.group(5) else 0
                    second = int(m.group(6)) if m.group(6) else 0
                    return datetime(year, month, day, hour, minute, second)
        return v


class ClaimDocumentItem(BaseModel):
    claim_doc_id: int = Field(..., description="ID from claim_documents table in Spring Boot")
    document_type: DocumentType = Field(..., description="Type of document (FIR, INVOICE, VEHICLE_DOCUMENT, etc.)")
    document_url: str = Field(..., description="Cloudinary download URL of the document PDF or image")


class ClaimPhotoItem(BaseModel):
    claim_doc_id: int = Field(..., description="ID from claim_documents table for the accident photo")
    photo_url: str = Field(..., description="Cloudinary download URL of the accident photo")
    existing_hashes: Optional[List[str]] = Field(
        default=None,
        description="Historical 64-bit perceptual hashes from past claims to check for recycled/duplicate photos",
    )


class AnalyzeClaimRequest(BaseModel):
    tenant_id: str | int = Field(..., description="Tenant identifier (e.g. TATA_AIG)")
    claim_id: int = Field(..., description="Primary key of the claim in Spring Boot")
    claim_number: str = Field(..., description="Human-readable claim reference number (e.g. CLM-2026-00042)")
    claim_amount: float = Field(..., description="Total claim amount claimed by the policyholder")
    ground_truth: ClaimGroundTruth = Field(..., description="Policy and incident ground truth facts")
    documents: List[ClaimDocumentItem] = Field(default_factory=list, description="List of non-photo claim documents")
    photos: List[ClaimPhotoItem] = Field(default_factory=list, description="List of accident photos to inspect")
