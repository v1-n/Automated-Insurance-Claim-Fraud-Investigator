from fastapi import FastAPI

try:
    from app.api.router import api_router
except ModuleNotFoundError:
    from api.router import api_router

app = FastAPI(title="FraudGuard AI Service")
app.include_router(api_router)