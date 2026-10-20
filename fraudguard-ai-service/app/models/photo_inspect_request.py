import re
from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, Field, field_validator


class IncidentPhotoContext(BaseModel):
    incident_date: date | datetime = Field(..., description="Date of accident from Claim entity")
    incident_city: str = Field(..., description="City of incident from Claim entity (e.g. Pune, Bengaluru)")
    incident_state: Optional[str] = Field(None, description="State of incident from Claim entity")
    incident_latitude: Optional[float] = Field(None, description="Optional GPS lat if available from mobile client")
    incident_longitude: Optional[float] = Field(None, description="Optional GPS long if available from mobile client")

    @field_validator("incident_date", mode="before")
    @classmethod
    def parse_incident_date(cls, v):
        if isinstance(v, (date, datetime)):
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


class PhotoInspectRequest(BaseModel):
    tenant_id: str | int = Field(..., description="Tenant code or ID (e.g. 'TATA_AIG')")
    claim_id: int = Field(..., description="Associated Claim ID")
    photo_id: int = Field(..., description="claim_doc_id in claim_documents table")
    photo_url: str = Field(..., description="Cloudinary URL of the uploaded accident photo")
    incident_context: IncidentPhotoContext = Field(..., description="Claim location and date context from database")
    existing_hashes: Optional[List[str]] = Field(
        default=None,
        description="Optional list of historical pHashes from past claims to detect duplicates/recycled photos",
    )
