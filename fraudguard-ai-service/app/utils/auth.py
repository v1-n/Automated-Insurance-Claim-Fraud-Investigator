import os
import logging
from fastapi import HTTPException, Security
from fastapi.security import APIKeyHeader

logger = logging.getLogger(__name__)

_api_key_header = APIKeyHeader(name="X-Internal-Key", auto_error=False)


async def verify_internal_key(key: str = Security(_api_key_header)):
    """FastAPI dependency that validates the X-Internal-Key header against AI_INTERNAL_KEY env var.
    When AI_INTERNAL_KEY is not set, authentication is disabled (development mode)."""
    expected = os.environ.get("AI_INTERNAL_KEY")
    if not expected:
        # No key configured -> dev/local mode, allow all requests
        return
    if not key or key != expected:
        logger.warning("Rejected request: invalid or missing X-Internal-Key header")
        raise HTTPException(status_code=401, detail="Invalid or missing X-Internal-Key")
