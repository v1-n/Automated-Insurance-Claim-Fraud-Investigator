from fastapi import APIRouter
from app.models.schemas import ClaimAnalysisRequest, ClaimAnalysisResponse
from app.services.rule_engine import evaluate_rules
from app.services.ocr_service import download_documents
from app.services.ml_service import ml_service

router = APIRouter()


@router.post("/api/v1/analyze-claim", response_model=ClaimAnalysisResponse)
async def analyze_claim(request: ClaimAnalysisRequest):

    # 1. Rule Engine Evaluation
    rule_score, triggered_rules = evaluate_rules(request)

    # 2. Document OCR Downloader & Keyword Scanner
    documents_bytes, ocr_insights = await download_documents(request.document_urls)

    # Count suspicious keywords across OCR insights
    suspicious_keywords = ["duplicate", "cancelled", "altered", "unverified", "forged", "stolen", "padded"]
    ocr_suspicious_count = 0
    for insight in ocr_insights:
        for word in suspicious_keywords:
            if word in insight.lower():
                ocr_suspicious_count += 1

    # 3. ML Model Fraud Probability Score (0.0 to 1.0)
    ml_prob = ml_service.predict_fraud(request, ocr_suspicious_count=ocr_suspicious_count)
    ml_score = round(ml_prob * 100.0, 2)

    # 4. Hybrid Final Fraud Score (50% Rule Engine + 50% ML Model)
    final_score = round((rule_score * 0.50) + (ml_score * 0.50), 2)

    # 5. Determine Risk Status Category
    if final_score >= 70.0:
        status = "HIGH_RISK"
    elif final_score >= 40.0:
        status = "MEDIUM_RISK"
    else:
        status = "LOW_RISK"

    return ClaimAnalysisResponse(
        claim_id=request.claim_id,
        rule_score=rule_score,
        ml_probability=round(ml_prob, 4),
        document_score=float(ocr_suspicious_count * 15.0),
        final_fraud_score=final_score,
        fraud_status=status,
        triggered_rules=triggered_rules,
        ocr_insights=ocr_insights
    )