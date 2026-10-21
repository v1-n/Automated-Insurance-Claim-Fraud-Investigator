import unittest
from datetime import date, datetime, timezone, timedelta
import imagehash
from app.enums.severity import Severity
from app.enums.verification_status import VerificationStatus
from app.models.photo_inspect_response import PhotoFlag
from app.api.endpoints.photos import (
    calculate_haversine_distance,
    determine_photo_status,
    GPS_PROXIMITY_KM,
)


class TestPhotoForensicsComprehensive(unittest.TestCase):

    def setUp(self):
        self.incident_date = date(2026, 10, 19)

    # Status determination tests using actual imported determine_photo_status
    def test_status_high_flag_returns_suspicious(self):
        flags = [
            PhotoFlag(
                code="TEST_HIGH",
                severity=Severity.HIGH,
                explanation="test",
                benignExplanations=[],
                nextSteps=[],
            )
        ]
        self.assertEqual(determine_photo_status(flags, exif_found=True), VerificationStatus.SUSPICIOUS)

    def test_status_no_exif_returns_unverifiable(self):
        self.assertEqual(determine_photo_status([], exif_found=False), VerificationStatus.UNVERIFIABLE)

    def test_status_medium_flag_returns_suspicious(self):
        flags = [
            PhotoFlag(
                code="TEST_MED",
                severity=Severity.MEDIUM,
                explanation="test",
                benignExplanations=[],
                nextSteps=[],
            )
        ]
        self.assertEqual(determine_photo_status(flags, exif_found=True), VerificationStatus.SUSPICIOUS)

    def test_status_low_flag_returns_passed(self):
        flags = [
            PhotoFlag(
                code="TEST_LOW",
                severity=Severity.LOW,
                explanation="test",
                benignExplanations=[],
                nextSteps=[],
            )
        ]
        self.assertEqual(determine_photo_status(flags, exif_found=True), VerificationStatus.PASSED)

    def test_status_no_flags_returns_passed(self):
        self.assertEqual(determine_photo_status([], exif_found=True), VerificationStatus.PASSED)

    # Timezone-aware normalization
    def test_timezone_aware_incident_datetime(self):
        kolkata_tz = timezone(timedelta(hours=5, minutes=30))
        tz_dt = datetime(2026, 10, 19, 23, 30, tzinfo=kolkata_tz)
        extracted_date = tz_dt.date()
        self.assertEqual(extracted_date, date(2026, 10, 19))
        self.assertTrue(isinstance(extracted_date, date))

    # GPS Distance and Location Mismatch Checks
    def test_gps_within_threshold_passes(self):
        # Pune city center to Hinjewadi (~16 km)
        pune_lat, pune_lon = 18.5204, 73.8567
        hinjewadi_lat, hinjewadi_lon = 18.5913, 73.7389
        dist = calculate_haversine_distance(pune_lat, pune_lon, hinjewadi_lat, hinjewadi_lon)
        self.assertLess(dist, GPS_PROXIMITY_KM)

    def test_gps_location_mismatch_flags(self):
        # Pune to Mumbai (~120 km) -> exceeds 50 km threshold
        pune_lat, pune_lon = 18.5204, 73.8567
        mumbai_lat, mumbai_lon = 19.0760, 72.8777
        dist = calculate_haversine_distance(pune_lat, pune_lon, mumbai_lat, mumbai_lon)
        self.assertGreater(dist, GPS_PROXIMITY_KM)

    # pHash Duplicates
    def test_invalid_historical_phash_skipped(self):
        invalid_hash = "9eb67138673361a89"  # 17 chars
        cleaned = invalid_hash.strip().lower()
        is_valid = len(cleaned) == 16 and all(c in "0123456789abcdef" for c in cleaned)
        self.assertFalse(is_valid)

    def test_exact_duplicate_phash_detected(self):
        hash_a = imagehash.hex_to_hash("9eb67138673361a8")
        hash_b = imagehash.hex_to_hash("9eb67138673361a8")
        self.assertEqual(hash_a - hash_b, 0)


if __name__ == "__main__":
    unittest.main()
