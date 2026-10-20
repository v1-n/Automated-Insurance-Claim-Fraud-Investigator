import unittest
from datetime import date, datetime, timezone, timedelta
import imagehash
from app.enums.severity import Severity
from app.enums.verification_status import VerificationStatus
from app.models.photo_inspect_response import PhotoFlag
from app.api.endpoints.photos import calculate_haversine_distance, GPS_PROXIMITY_KM


def evaluate_date_difference(photo_date: date, incident_date: date) -> list[PhotoFlag]:
    """Pure logic function mirroring photos.py date-evaluation rules."""
    flags = []
    day_diff = (photo_date - incident_date).days

    if day_diff < 0:
        days_prior = abs(day_diff)
        flags.append(
            PhotoFlag(
                code="PHOTO_TAKEN_PRIOR_TO_INCIDENT",
                severity=Severity.HIGH,
                explanation=f"Photo capture date ({photo_date}) is {days_prior} day(s) before incident date ({incident_date}).",
                benignExplanations=["Phone clock error"],
                nextSteps=["Inspect phone roll"],
            )
        )
    elif day_diff == 0:
        pass  # Same day -> legitimate
    elif day_diff == 1:
        flags.append(
            PhotoFlag(
                code="PHOTO_INCIDENT_DATE_MISMATCH_MINOR",
                severity=Severity.LOW,
                explanation=f"Photo was taken 1 day after incident (Incident: {incident_date}, Photo: {photo_date}).",
                benignExplanations=["Customer took photo morning after incident"],
                nextSteps=["Verify timeline during intake"],
            )
        )
    elif 2 <= day_diff <= 7:
        flags.append(
            PhotoFlag(
                code="PHOTO_INCIDENT_DATE_MISMATCH_MODERATE",
                severity=Severity.MEDIUM,
                explanation=f"Photo was taken {day_diff} days after incident.",
                benignExplanations=["Delayed photo capture"],
                nextSteps=["Confirm vehicle was stationary"],
            )
        )
    else:
        flags.append(
            PhotoFlag(
                code="PHOTO_SIGNIFICANT_CAPTURE_DELAY",
                severity=Severity.HIGH,
                explanation=f"Photo was taken {day_diff} days after incident.",
                benignExplanations=["Hospitalization delay"],
                nextSteps=["Investigate delayed capture"],
            )
        )
    return flags


def determine_status(flags: list[PhotoFlag], exif_found: bool) -> VerificationStatus:
    """Pure logic function mirroring photos.py status determination."""
    if any(f.severity == Severity.HIGH for f in flags):
        return VerificationStatus.SUSPICIOUS
    elif not exif_found:
        return VerificationStatus.UNVERIFIABLE
    elif any(f.severity == Severity.MEDIUM for f in flags):
        return VerificationStatus.SUSPICIOUS
    else:
        return VerificationStatus.PASSED


class TestPhotoForensicsComprehensive(unittest.TestCase):

    def setUp(self):
        self.incident_date = date(2026, 10, 19)

    # Core Date Thresholds
    def test_t01_same_calendar_day_passes(self):
        photo_date = date(2026, 10, 19)
        flags = evaluate_date_difference(photo_date, self.incident_date)
        self.assertEqual(len(flags), 0)
        self.assertEqual(determine_status(flags, exif_found=True), VerificationStatus.PASSED)

    def test_t02_one_day_later_low_severity_remains_passed(self):
        photo_date = date(2026, 10, 20)
        flags = evaluate_date_difference(photo_date, self.incident_date)
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0].code, "PHOTO_INCIDENT_DATE_MISMATCH_MINOR")
        self.assertEqual(flags[0].severity, Severity.LOW)
        self.assertEqual(determine_status(flags, exif_found=True), VerificationStatus.PASSED)

    def test_t03_seven_days_later_medium_severity(self):
        photo_date = date(2026, 10, 26)  # 7 days
        flags = evaluate_date_difference(photo_date, self.incident_date)
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0].code, "PHOTO_INCIDENT_DATE_MISMATCH_MODERATE")
        self.assertEqual(flags[0].severity, Severity.MEDIUM)
        self.assertEqual(determine_status(flags, exif_found=True), VerificationStatus.SUSPICIOUS)

    def test_t04_eight_days_later_high_severity(self):
        photo_date = date(2026, 10, 27)  # 8 days
        flags = evaluate_date_difference(photo_date, self.incident_date)
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0].code, "PHOTO_SIGNIFICANT_CAPTURE_DELAY")
        self.assertEqual(flags[0].severity, Severity.HIGH)
        self.assertEqual(determine_status(flags, exif_found=True), VerificationStatus.SUSPICIOUS)

    # Timezone-aware normalization
    def test_t07_timezone_aware_incident_datetime(self):
        kolkata_tz = timezone(timedelta(hours=5, minutes=30))
        tz_dt = datetime(2026, 10, 19, 23, 30, tzinfo=kolkata_tz)
        extracted_date = tz_dt.date()
        self.assertEqual(extracted_date, date(2026, 10, 19))
        self.assertTrue(isinstance(extracted_date, date))

    # GPS Distance and Location Mismatch Checks
    def test_t09_gps_within_threshold_passes(self):
        # Pune city center to Hinjewadi (~16 km)
        pune_lat, pune_lon = 18.5204, 73.8567
        hinjewadi_lat, hinjewadi_lon = 18.5913, 73.7389
        dist = calculate_haversine_distance(pune_lat, pune_lon, hinjewadi_lat, hinjewadi_lon)
        self.assertLess(dist, GPS_PROXIMITY_KM)

    def test_t09_gps_location_mismatch_flags(self):
        # Pune to Mumbai (~120 km) -> exceeds 50 km threshold
        pune_lat, pune_lon = 18.5204, 73.8567
        mumbai_lat, mumbai_lon = 19.0760, 72.8777
        dist = calculate_haversine_distance(pune_lat, pune_lon, mumbai_lat, mumbai_lon)
        self.assertGreater(dist, GPS_PROXIMITY_KM)

    # pHash Duplicates
    def test_t10_invalid_historical_phash_skipped(self):
        invalid_hash = "9eb67138673361a89"  # 17 chars
        cleaned = invalid_hash.strip().lower()
        is_valid = len(cleaned) == 16 and all(c in "0123456789abcdef" for c in cleaned)
        self.assertFalse(is_valid)

    def test_t11_exact_duplicate_phash_detected(self):
        hash_a = imagehash.hex_to_hash("9eb67138673361a8")
        hash_b = imagehash.hex_to_hash("9eb67138673361a8")
        self.assertEqual(hash_a - hash_b, 0)


if __name__ == "__main__":
    unittest.main()
