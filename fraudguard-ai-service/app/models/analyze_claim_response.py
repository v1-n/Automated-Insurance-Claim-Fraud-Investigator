from typing import List, Optional
from pydantic import BaseModel, Field
from app.enums.severity import Severity
from app.enums.risk_level import RiskLevel
from app.enums.recommendation import  Recommendation


class ClaimEvidenceFlag(BaseModel):
    flag_id: str = Field(..., description="Unique generated identifier for the flag (e.g. FLAG-101-01)")
    code: str = Field(..., description="Machine-readable code (e.g. FIR_VEHICLE_MISMATCH, PHOTO_EXACT_DUPLICATE_DETECTED)")
    category: str = Field(..., description="Category: DOCUMENT_INCONSISTENCY, PHOTO_FORENSICS, CLAIM_RULES")
    severity: Severity = Field(..., description="LOW, MEDIUM, or HIGH")
    source: str = Field(..., description="Subsystem that generated the flag: document-ocr, photo-forensics, claim-rules")
    explanation: str = Field(..., description="Human-readable explanation of why this flag was raised")
    benign_explanations: List[str] = Field(
        default_factory=list,
        description="Plausible non-fraud explanations to avoid false positives",
    )
    next_steps: List[str] = Field(
        default_factory=list,
        description="Actionable guidance for the insurance investigator to verify the flag",
    )
    confidence: float = Field(default=0.85, description="Confidence score of the detection (0.0 to 1.0)")


class PhotoHashResult(BaseModel):
    claim_doc_id: int
    phash: str


class DocumentSummaryResult(BaseModel):
    claim_doc_id: int
    document_type: str
    vehicle_verified: bool
    text_length: int


class ClaimAnalysisDetails(BaseModel):
    total_documents_analyzed: int
    total_photos_analyzed: int
    document_summaries: List[DocumentSummaryResult] = Field(
        default_factory=list,
        description="Verification details for each analyzed document",
    )
    photo_hashes: List[PhotoHashResult] = Field(
        default_factory=list,
        description="Generated pHashes for each uploaded photo so Spring Boot can persist them in DB",
    )



class AnalyzeClaimResponse(BaseModel):
    claim_id: int
    tenant_id: str | int
    risk_score: int = Field(..., description="Aggregated risk score from 0 (clean) to 100 (high risk)")
    risk_level: RiskLevel = Field(..., description="LOW, MEDIUM, or HIGH risk category")
    recommendation: Recommendation = Field(..., description="FAST_TRACK, REVIEW, or INVESTIGATE")
    summary: str = Field(..., description="Executive summary explaining the overall assessment")
    flags: List[ClaimEvidenceFlag] = Field(
        default_factory=list,
        description="Structured PRD Section 16 compliant list of evidence flags",
    )
    details: ClaimAnalysisDetails
