from fastapi import APIRouter, Depends
from app.api.endpoints import health, documents, photos, analyze
from app.utils.auth import verify_internal_key

api_router = APIRouter()

# Public endpoint for health checks & container liveness probes (no auth required)
api_router.include_router(health.router)

# Protected endpoints requiring X-Internal-Key authentication
api_router.include_router(documents.router, dependencies=[Depends(verify_internal_key)])
api_router.include_router(photos.router, dependencies=[Depends(verify_internal_key)])
api_router.include_router(analyze.router, dependencies=[Depends(verify_internal_key)])
