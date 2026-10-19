from typing import Optional, List
from pydantic import BaseModel, Field
from app.enums.severity import Severity
from app.enums.verification_status import VerificationStatus


class PhotoForensicDetails(BaseModel):
    camera_make: Optional[str] = None
    camera_model: Optional[str] = None
    captured_at: Optional[str] = None
    software_tag: Optional[str] = None
    gps_latitude: Optional[float] = None
    gps_longitude: Optional[float] = None


class PhotoFlag(BaseModel):
    code: str = Field(..., description="Unique flag code (e.g. PHOTO_EDITING_SOFTWARE_DETECTED)")
    severity: Severity = Field(..., description="Severity level: LOW, MEDIUM, or HIGH")
    explanation: str = Field(..., description="Detailed explanation of the forensic flag")
    benignExplanations: List[str] = Field(default_factory=list, description="Plausible non-fraud explanations")
    nextSteps: List[str] = Field(default_factory=list, description="Action items for the investigator")


class PhotoInspectResponse(BaseModel):
    photo_id: int
    phash: str = Field(..., description="64-bit perceptual hash for cross-claim duplicate matching")
    exif_found: bool
    is_manipulated: bool
    forensic_details: PhotoForensicDetails
    flags: List[PhotoFlag] = Field(default_factory=list)
    verification_status: VerificationStatus
    summary: str