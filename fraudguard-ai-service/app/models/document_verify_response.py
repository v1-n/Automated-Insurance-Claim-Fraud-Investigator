from typing import List, Optional
from pydantic import BaseModel, Field
from app.enums.severity import Severity
from app.enums.verification_status import VerificationStatus


class DocumentFlag(BaseModel):
    code: str = Field(..., description="Unique flag code (e.g. FIR_VEHICLE_MISMATCH, FIR_OBSOLETE_LEGAL_CODE)")
    severity: Severity = Field(..., description="Severity level: LOW, MEDIUM, or HIGH")
    document_id: int = Field(..., description="ID of the document that triggered the flag")
    explanation: str = Field(..., description="Detailed explanation of the issue")
    benignExplanations: List[str] = Field(default_factory=list, description="Plausible non-fraud explanations")
    nextSteps: List[str] = Field(default_factory=list, description="Action items for the investigator")


class ExtractedDocumentSummary(BaseModel):
    document_id: int
    document_type: str
    text_length: int
    extraction_failed: bool = False


class DocumentVerifyResponse(BaseModel):
    claim_id: int
    verification_status: VerificationStatus
    total_documents_analyzed: int
    extracted_documents: List[ExtractedDocumentSummary] = Field(default_factory=list)
    flags: List[DocumentFlag] = Field(default_factory=list)
    summary: str
