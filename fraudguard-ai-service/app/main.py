from fastapi import FastAPI
from app.api.router import api_router
import  logging


# Configure global logging format
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

logger = logging.getLogger("fraudguard-ai-service")
logger.info("Initializing FraudGuard AI Service...")


app = FastAPI(title="FraudGuard AI Service")
app.include_router(api_router)