from enum import StrEnum
class Recommendation(StrEnum):
    FAST_TRACK = "FAST_TRACK"    # Score 0-25: No red flags, approve quickly
    REVIEW = "REVIEW"            # Score 26-60: Minor discrepancies or missing EXIF
    INVESTIGATE = "INVESTIGATE"  # Score 61-100: Multiple high-severity red flags (duplicate photo, mismatch, etc.)
