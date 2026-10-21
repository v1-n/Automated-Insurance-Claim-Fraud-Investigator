import unittest
import os
from fastapi.testclient import TestClient
from app.main import app


class TestPhotoInspectionEndpoint(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def test_inspect_photo_requires_auth_when_configured(self):
        # Save previous env
        old_disabled = os.environ.get("AUTH_DISABLED")
        old_key = os.environ.get("AI_INTERNAL_KEY")

        try:
            os.environ["AUTH_DISABLED"] = "false"
            os.environ["AI_INTERNAL_KEY"] = "photo-test-secret"

            payload = {
                "tenant_id": "TATA_AIG",
                "claim_id": 101,
                "photo_id": 1,
                "photo_url": "https://res.cloudinary.com/aafdcxyl/test.jpg",
                "incident_context": {
                    "incident_date": "2026-10-19",
                    "incident_city": "Bengaluru",
                    "incident_state": "Karnataka",
                },
            }

            # 1. No key -> 401
            res_no_key = self.client.post("/inspect-photo", json=payload)
            self.assertEqual(res_no_key.status_code, 401)

            # 2. Wrong key -> 401
            res_wrong_key = self.client.post(
                "/inspect-photo", json=payload, headers={"X-Internal-Key": "wrong-key"}
            )
            self.assertEqual(res_wrong_key.status_code, 401)

        finally:
            if old_disabled is not None:
                os.environ["AUTH_DISABLED"] = old_disabled
            else:
                os.environ.pop("AUTH_DISABLED", None)

            if old_key is not None:
                os.environ["AI_INTERNAL_KEY"] = old_key
            else:
                os.environ.pop("AI_INTERNAL_KEY", None)

    def test_inspect_photo_invalid_url_scheme_fails(self):
        # With auth disabled for functional testing
        old_disabled = os.environ.get("AUTH_DISABLED")
        try:
            os.environ["AUTH_DISABLED"] = "true"

            payload = {
                "tenant_id": "TATA_AIG",
                "claim_id": 101,
                "photo_id": 1,
                "photo_url": "http://insecure-domain.com/photo.jpg",  # Insecure HTTP
                "incident_context": {
                    "incident_date": "2026-10-19",
                    "incident_city": "Bengaluru",
                    "incident_state": "Karnataka",
                },
            }
            res = self.client.post("/inspect-photo", json=payload)
            # Should fail due to non-HTTPS and disallowed host
            self.assertEqual(res.status_code, 400)
            self.assertIn("Failed to process image", res.json()["detail"])
        finally:
            if old_disabled is not None:
                os.environ["AUTH_DISABLED"] = old_disabled
            else:
                os.environ.pop("AUTH_DISABLED", None)


if __name__ == "__main__":
    unittest.main()
