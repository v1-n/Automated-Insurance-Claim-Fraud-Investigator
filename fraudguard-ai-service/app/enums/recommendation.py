from enum import StrEnum


class Recommendation(StrEnum):
    FAST_TRACK = "FAST_TRACK"    # Score < 25 with no MEDIUM or HIGH flags
    REVIEW = "REVIEW"            # Score >= 25 OR any MEDIUM flag
    INVESTIGATE = "INVESTIGATE"  # Score >= 60 OR any HIGH flag
