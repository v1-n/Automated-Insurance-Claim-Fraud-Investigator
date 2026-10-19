from enum import StrEnum


class VerificationStatus(StrEnum):
    PASSED = "PASSED"
    SUSPICIOUS = "SUSPICIOUS"
    FAILED = "FAILED"
