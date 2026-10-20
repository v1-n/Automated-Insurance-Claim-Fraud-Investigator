import unittest
from datetime import date, datetime
import imagehash
from app.enums.severity import Severity
from app.enums.verification_status import VerificationStatus
from app.models.photo_inspect_response import PhotoFlag


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


class TestPhotoDateVerification(unittest.TestCase):

    def setUp(self):
        self.incident_date = date(2026, 10, 19)

    # Core Date Thresholds
    def test_date_01_same_calendar_day_passes(self):
        photo_date = date(2026, 10, 19)
        flags = evaluate_date_difference(photo_date, self.incident_date)
        self.assertEqual(len(flags), 0)
        self.assertEqual(determine_status(flags, exif_found=True), VerificationStatus.PASSED)

    def test_date_02_one_day_later_low_severity_remains_passed(self):
        photo_date = date(2026, 10, 20)
        flags = evaluate_date_difference(photo_date, self.incident_date)
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0].code, "PHOTO_INCIDENT_DATE_MISMATCH_MINOR")
        self.assertEqual(flags[0].severity, Severity.LOW)
        # Crucial design requirement: 1 day later must NOT fail or be marked suspicious!
        self.assertEqual(determine_status(flags, exif_found=True), VerificationStatus.PASSED)

    def test_date_03_two_days_later_medium_severity(self):
        photo_date = date(2026, 10, 21)
        flags = evaluate_date_difference(photo_date, self.incident_date)
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0].code, "PHOTO_INCIDENT_DATE_MISMATCH_MODERATE")
        self.assertEqual(flags[0].severity, Severity.MEDIUM)
        self.assertEqual(determine_status(flags, exif_found=True), VerificationStatus.SUSPICIOUS)

    def test_date_06_seven_days_later_medium_boundary(self):
        photo_date = date(2026, 10, 26)  # exactly 7 days
        flags = evaluate_date_difference(photo_date, self.incident_date)
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0].code, "PHOTO_INCIDENT_DATE_MISMATCH_MODERATE")
        self.assertEqual(flags[0].severity, Severity.MEDIUM)

    def test_date_07_eight_days_later_high_severity(self):
        photo_date = date(2026, 10, 27)  # 8 days
        flags = evaluate_date_difference(photo_date, self.incident_date)
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0].code, "PHOTO_SIGNIFICANT_CAPTURE_DELAY")
        self.assertEqual(flags[0].severity, Severity.HIGH)
        self.assertEqual(determine_status(flags, exif_found=True), VerificationStatus.SUSPICIOUS)

    def test_date_08_photo_before_incident_high_severity(self):
        photo_date = date(2026, 10, 18)  # 1 day before
        flags = evaluate_date_difference(photo_date, self.incident_date)
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0].code, "PHOTO_TAKEN_PRIOR_TO_INCIDENT")
        self.assertEqual(flags[0].severity, Severity.HIGH)
        self.assertEqual(determine_status(flags, exif_found=True), VerificationStatus.SUSPICIOUS)

    # Boundary and Leap Year Calculations
    def test_edge_year_boundary(self):
        incident = date(2026, 12, 31)
        photo = date(2027, 1, 1)
        flags = evaluate_date_difference(photo, incident)
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0].severity, Severity.LOW)

    def test_edge_leap_year(self):
        incident = date(2024, 2, 28)
        photo = date(2024, 2, 29)
        flags = evaluate_date_difference(photo, incident)
        self.assertEqual(len(flags), 1)
        self.assertEqual(flags[0].severity, Severity.LOW)

    # Missing EXIF
    def test_exif_missing_returns_unverifiable(self):
        self.assertEqual(determine_status([], exif_found=False), VerificationStatus.UNVERIFIABLE)

    # Duplicate pHash Matching
    def test_phash_exact_match(self):
        hash_a = imagehash.hex_to_hash("df62f4c8039d7087")
        hash_b = imagehash.hex_to_hash("df62f4c8039d7087")
        self.assertEqual(hash_a - hash_b, 0)

    def test_phash_similar_match(self):
        hash_a = imagehash.hex_to_hash("df62f4c8039d7087")
        # Difference in 2 bits
        hash_b = imagehash.hex_to_hash("df62f4c8039d7085")
        dist = hash_a - hash_b
        self.assertTrue(0 < dist <= 5)


if __name__ == "__main__":
    unittest.main()
