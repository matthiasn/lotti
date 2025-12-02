"""Main entry point for the AI proxy service"""

import logging
import os

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api.routes import router
from shared.auth import APIKeyAuthMiddleware
from .middleware.rate_limit import limiter, rate_limit_handler
from .middleware.request_id import RequestIDMiddleware
from slowapi.errors import RateLimitExceeded

# Load environment variables from .env file
load_dotenv()

# Configure logging
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

logger = logging.getLogger(__name__)


# Create FastAPI app
app = FastAPI(
    title="AI Proxy Service",
    description="OpenAI-compatible proxy for Gemini and other AI providers",
    version="0.1.0",
)

# Add rate limiter state
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, rate_limit_handler)

# Add CORS middleware
# Configure allowed origins from environment variable
# Example: CORS_ALLOWED_ORIGINS="https://app.lotti.com,https://dev.lotti.com"
cors_origins_str = os.getenv("CORS_ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080")
cors_origins = [origin.strip() for origin in cors_origins_str.split(",") if origin.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)

# Add API key authentication middleware (exempts /health, /metrics, /docs)
app.add_middleware(APIKeyAuthMiddleware, exempt_paths=["/health", "/metrics", "/docs", "/openapi.json", "/redoc"])

# Add request ID middleware for tracing
app.add_middleware(RequestIDMiddleware)

# Include routes
app.include_router(router)


@app.on_event("startup")
async def startup_event():
    """Application startup event"""
    logger.info("Starting AI Proxy Service...")
    logger.info("AI Proxy Service started successfully")


@app.on_event("shutdown")
async def shutdown_event():
    """Application shutdown event"""
    logger.info("Shutting down AI Proxy Service...")
    logger.info("AI Proxy Service shutdown complete")


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "8002"))
    uvicorn.run(app, host="0.0.0.0", port=port)  # nosec B104
