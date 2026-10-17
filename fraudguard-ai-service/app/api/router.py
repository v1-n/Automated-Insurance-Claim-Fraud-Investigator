from fastapi import APIRouter
from app.api.endpoints import health
from app.api.endpoints import documents,analyze

api_router = APIRouter()

api_router.include_router(health.router)
api_router.include_router(documents.router)
# api_router.include_router(analyze.router)

