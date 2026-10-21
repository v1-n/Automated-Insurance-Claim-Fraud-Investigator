import os
import hmac
import logging
from fastapi import HTTPException, Security
from fastapi.security import APIKeyHeader

logger = logging.getLogger(__name__)

_api_key_header = APIKeyHeader(name="X-Internal-Key", auto_error=False)


async def verify_internal_key(key: str = Security(_api_key_header)):
    """
    FastAPI dependency that validates the X-Internal-Key header against AI_INTERNAL_KEY env var.
    
    Security design:
      - Fails closed in production: if AI_INTERNAL_KEY is not set, requests are rejected with HTTP 500,
        preventing an accidentally unauthenticated deployment on Render / Cloud platforms.
      - Local development override: Set AUTH_DISABLED=true to explicitly bypass auth during local dev.
      - Uses hmac.compare_digest to prevent timing attacks during key comparison.
    """
    auth_disabled = os.environ.get("AUTH_DISABLED", "").strip().lower() in ("true", "1", "yes")
    if auth_disabled:
        return

    expected = os.environ.get("AI_INTERNAL_KEY")
    if not expected:
        logger.error(
            "Authentication failed closed: AI_INTERNAL_KEY environment variable is not set, "
            "and AUTH_DISABLED is not enabled. Rejecting request."
        )
        raise HTTPException(
            status_code=503,
            detail="Server authentication configuration error: AI_INTERNAL_KEY is not configured.",
        )

    if not key or not hmac.compare_digest(key, expected):
        logger.warning("Rejected request: invalid or missing X-Internal-Key header")
        raise HTTPException(status_code=401, detail="Invalid or missing X-Internal-Key")
