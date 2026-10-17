from typing import List
from pydantic import BaseModel,Field
from datetime import  datetime,date
from app.enums.document_type import DocumentType

class DocumentItem(BaseModel):
    document_id: int = Field(..., description="Document ID in Spring Boot database")
    document_type: DocumentType = Field(..., description="Document classification (FIR, INVOICE, etc.)")
    document_url: str = Field(..., description="Cloudinary or public URL to download the document")

class GroundTruth(BaseModel):
    vehicle_number: str = Field(..., description="Vehicle registration plate (e.g., MH12AB1234)")
    vehicle_make_model: str = Field(..., description="Manufacturer and model (e.g., Hyundai i20)")
    incident_date: date | datetime = Field(..., description="When the incident took place")
    claimed_amount: float = Field(..., ge=0.0, description="Total claim amount in INR")
    policy_start_date: date | datetime = Field(..., description="Insurance policy coverage start date")
    policy_end_date: date | datetime = Field(..., description="Insurance policy coverage expiration date")

class DocumentVerifyRequest(BaseModel):
    tenant_id: str | int = Field(..., description="Tenant identifier (e.g., 'TATA_AIG' or numeric ID)")
    claim_id: int = Field(..., description="Associated claim ID")
    documents: List[DocumentItem] = Field(..., min_length=1, description="List of documents to verify")
    ground_truth: GroundTruth = Field(..., description="Verified baseline claim & policy ground truth from DB")
