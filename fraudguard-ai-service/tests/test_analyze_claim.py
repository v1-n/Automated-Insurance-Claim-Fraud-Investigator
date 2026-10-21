import unittest
import os
from datetime import date, timedelta
from app.enums.severity import Severity
from app.enums.risk_level import RiskLevel
from app.enums.recommendation import Recommendation
from app.models.analyze_claim_response import ClaimEvidenceFlag
from app.api.endpoints.analyze import calculate_claim_risk_score
from app.api.endpoints.documents import evaluate_vehicle_registration


class TestAnalyzeClaimScoring(unittest.TestCase):

    def test_clean_claim_scores_zero_fast_track(self):
        score, level, rec = calculate_claim_risk_score(flags=[], claim_amount=10000, idv=100000)
        self.assertEqual(score, 0)
        self.assertEqual(level, RiskLevel.LOW)
        self.assertEqual(rec, Recommendation.FAST_TRACK)

    def test_single_high_flag_escalates_to_investigate(self):
        flag = ClaimEvidenceFlag(
            flag_id="FLAG-01",
            code="PHOTO_EXACT_DUPLICATE_DETECTED",
            category="PHOTO_FORENSICS",
            severity=Severity.HIGH,
            source="photo-forensics",
            explanation="Duplicate photo",
        )
        score, level, rec = calculate_claim_risk_score(flags=[flag], claim_amount=10000, idv=100000)
        self.assertEqual(score, 35)
        self.assertEqual(level, RiskLevel.HIGH)
        self.assertEqual(rec, Recommendation.INVESTIGATE)

    def test_single_medium_flag_routes_to_review(self):
        flag = ClaimEvidenceFlag(
            flag_id="FLAG-01",
            code="FIR_EXTRACTION_FAILED",
            category="DOCUMENT_INCONSISTENCY",
            severity=Severity.MEDIUM,
            source="document-ocr",
            explanation="Extraction failed",
        )
        score, level, rec = calculate_claim_risk_score(flags=[flag], claim_amount=10000, idv=100000)
        self.assertEqual(score, 15)
        self.assertEqual(level, RiskLevel.MEDIUM)
        self.assertEqual(rec, Recommendation.REVIEW)

    def test_claim_exceeding_idv_adds_15_points(self):
        # Claim amount 90k on 100k IDV (>80%)
        score, level, rec = calculate_claim_risk_score(flags=[], claim_amount=90000, idv=100000)
        self.assertEqual(score, 15)
        self.assertEqual(level, RiskLevel.LOW)
        self.assertEqual(rec, Recommendation.FAST_TRACK)

    def test_score_clamped_at_100(self):
        flags = [
            ClaimEvidenceFlag(
                flag_id=f"FLAG-{i}",
                code=f"CODE-{i}",
                category="TEST",
                severity=Severity.HIGH,
                source="test",
                explanation="test",
            )
            for i in range(5)  # 5 * 35 = 175
        ]
        score, level, rec = calculate_claim_risk_score(flags=flags, claim_amount=10000, idv=100000)
        self.assertEqual(score, 100)
        self.assertEqual(level, RiskLevel.HIGH)
        self.assertEqual(rec, Recommendation.INVESTIGATE)


class TestVehicleMatcher(unittest.TestCase):

    def test_exact_match(self):
        flags = evaluate_vehicle_registration(
            doc_type="FIR",
            doc_id=1,
            text="The accident vehicle was KA-53-C-1095 at the site.",
            vehicle_number="KA53C1095",
        )
        self.assertEqual(len(flags), 0)

    def test_ocr_normalized_character_match(self):
        # Letter 'O' instead of digit '0'
        flags = evaluate_vehicle_registration(
            doc_type="FIR",
            doc_id=1,
            text="Vehicle registration KA53C1O95 was inspected.",
            vehicle_number="KA53C1095",
        )
        self.assertEqual(len(flags), 0)

    def test_near_match_gives_low_severity_advisory(self):
        # 1 character error e.g. B vs 8 or single digit flip
        flags = evaluate_vehicle_registration(
            doc_type="FIR",
            doc_id=1,
            text="Car plate MH12AB1234 recorded.",
            vehicle_number="MH12AR1234",
        )
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0]["code"], "FIR_VEHICLE_NEAR_MATCH")
        self.assertEqual(flags[0]["severity"], Severity.LOW)

    def test_mismatch_with_conflicting_plate_gives_high(self):
        flags = evaluate_vehicle_registration(
            doc_type="FIR",
            doc_id=1,
            text="The colliding vehicle registration was DL01AB9999.",
            vehicle_number="KA53C1095",
        )
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0]["code"], "FIR_VEHICLE_MISMATCH")
        self.assertEqual(flags[0]["severity"], Severity.HIGH)

    def test_not_found_gives_high(self):
        flags = evaluate_vehicle_registration(
            doc_type="FIR",
            doc_id=1,
            text="General police diary entry without any registration numbers recorded.",
            vehicle_number="KA53C1095",
        )
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0]["code"], "FIR_VEHICLE_NOT_FOUND")
        self.assertEqual(flags[0]["severity"], Severity.HIGH)

    def test_invalid_short_vehicle_placeholder(self):
        flags = evaluate_vehicle_registration(
            doc_type="FIR",
            doc_id=1,
            text="Sample document text",
            vehicle_number="j",
        )
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0]["code"], "INVALID_VEHICLE_REGISTRATION_NUMBER")
        self.assertEqual(flags[0]["severity"], Severity.HIGH)


class TestFullAnalyzeClaimAPI(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        os.environ["AUTH_DISABLED"] = "true"
        from fastapi.testclient import TestClient
        from app.main import app
        cls.client = TestClient(app)

    def test_future_date_single_claim_rule_flag(self):
        future_date = (date.today() + timedelta(days=5)).isoformat()
        payload = {
            "tenant_id": "TATA_AIG",
            "claim_id": 201,
            "claim_number": "CLAIM-FUTURE",
            "claim_amount": 10000,
            "ground_truth": {
                "vehicle_number": "KA53C1095",
                "policy_number": "POL123",
                "policy_start_date": "2026-01-01",
                "policy_end_date": "2027-12-31",
                "idv_amount": 500000,
                "incident_date": future_date,
                "incident_city": "Bengaluru",
                "incident_state": "Karnataka",
                "incident_latitude": 12.9716,
                "incident_longitude": 77.5946,
            },
            "documents": [],
            "photos": [],
        }
        res = self.client.post("/api/v1/analyze-claim", json=payload)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        future_flags = [f for f in data["flags"] if f["code"] == "INCIDENT_DATE_IN_FUTURE"]
        self.assertEqual(len(future_flags), 1)
        self.assertEqual(future_flags[0]["severity"], "HIGH")
        self.assertEqual(future_flags[0]["source"], "claim-rules")
        self.assertEqual(data["recommendation"], "INVESTIGATE")

    def test_two_photos_do_not_duplicate_incident_date_flag(self):
        future_date = (date.today() + timedelta(days=5)).isoformat()
        payload = {
            "tenant_id": "TATA_AIG",
            "claim_id": 202,
            "claim_number": "CLAIM-TWO-PHOTOS",
            "claim_amount": 10000,
            "ground_truth": {
                "vehicle_number": "KA53C1095",
                "policy_number": "POL123",
                "policy_start_date": "2026-01-01",
                "policy_end_date": "2027-12-31",
                "idv_amount": 500000,
                "incident_date": future_date,
                "incident_city": "Bengaluru",
                "incident_state": "Karnataka",
                "incident_latitude": 12.9716,
                "incident_longitude": 77.5946,
            },
            "documents": [],
            "photos": [
                {
                    "claim_doc_id": 1,
                    "photo_url": "https://res.cloudinary.com/aafdcxyl/nonexistent1.jpg",
                    "existing_hashes": [],
                },
                {
                    "claim_doc_id": 2,
                    "photo_url": "https://res.cloudinary.com/aafdcxyl/nonexistent2.jpg",
                    "existing_hashes": [],
                },
            ],
        }
        res = self.client.post("/api/v1/analyze-claim", json=payload)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        future_flags = [f for f in data["flags"] if f["code"] == "INCIDENT_DATE_IN_FUTURE"]
        # Must be exactly 1, NOT duplicated twice!
        self.assertEqual(len(future_flags), 1)


if __name__ == "__main__":
    unittest.main()
