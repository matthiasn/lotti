"""Main entry point for the credits service"""

import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api.routes import router
from .container import container
from .middleware.auth import APIKeyAuthMiddleware

# Configure logging
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler"""
    # Startup
    logger.info("Starting Credits Service...")

    # Connect to TigerBeetle
    tigerbeetle_client = container.get_tigerbeetle_client()
    await tigerbeetle_client.connect()

    logger.info("Credits Service started successfully")

    yield

    # Shutdown
    logger.info("Shutting down Credits Service...")
    await tigerbeetle_client.disconnect()
    logger.info("Credits Service shutdown complete")


# Create FastAPI app
app = FastAPI(
    title="Credits Service",
    description="A ledger-based service for managing user credits",
    version="0.1.0",
    lifespan=lifespan,
)

# Add CORS middleware
# Configure allowed origins from environment variable
# Example: CORS_ALLOWED_ORIGINS="https://app.lotti.com,https://dev.lotti.com"
cors_origins_str = os.getenv("CORS_ALLOWED_ORIGINS", "http://localhost:3000")
cors_origins = [origin.strip() for origin in cors_origins_str.split(",") if origin.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)

# Add API key authentication middleware
app.add_middleware(APIKeyAuthMiddleware)

# Include routes
app.include_router(router, prefix="/api/v1")


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "8001"))
    uvicorn.run(app, host="0.0.0.0", port=port)  # nosec B104
