"""Main entry point for the credits service"""

import logging
import os
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .api.routes import router
from .container import container
from .core.exceptions import (
    AccountAlreadyExistsException,
    AccountNotFoundException,
    InsufficientBalanceException,
    InvalidAmountException,
)

# Configure logging
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
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


# Exception handlers
@app.exception_handler(AccountNotFoundException)
async def account_not_found_handler(request: Request, exc: AccountNotFoundException) -> JSONResponse:
    logger.warning(f"Account not found: {exc}")
    return JSONResponse(status_code=404, content={"detail": str(exc)})


@app.exception_handler(AccountAlreadyExistsException)
async def account_already_exists_handler(request: Request, exc: AccountAlreadyExistsException) -> JSONResponse:
    logger.warning(f"Account already exists: {exc}")
    return JSONResponse(status_code=409, content={"detail": str(exc)})


@app.exception_handler(InvalidAmountException)
async def invalid_amount_handler(request: Request, exc: InvalidAmountException) -> JSONResponse:
    logger.warning(f"Invalid amount: {exc}")
    return JSONResponse(status_code=400, content={"detail": str(exc)})


@app.exception_handler(InsufficientBalanceException)
async def insufficient_balance_handler(request: Request, exc: InsufficientBalanceException) -> JSONResponse:
    logger.warning(f"Insufficient balance: {exc}")
    return JSONResponse(status_code=402, content={"detail": str(exc)})


# Add CORS middleware
# Configure allowed origins from environment variable
# Example: CORS_ALLOWED_ORIGINS="https://app.lotti.com,https://dev.lotti.com"
cors_origins_str = os.getenv("CORS_ALLOWED_ORIGINS", "http://localhost:3000")
cors_origins = [origin.strip() for origin in cors_origins_str.split(",") if origin.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)

# Include routes
app.include_router(router, prefix="/api/v1")


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "8001"))
    uvicorn.run(app, host="0.0.0.0", port=port)  # nosec B104
