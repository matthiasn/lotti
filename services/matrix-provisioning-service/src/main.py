"""Main entry point for the matrix provisioning service"""

import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from shared.auth import APIKeyAuthMiddleware

from .api.routes import router
from .container import container

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

logger = logging.getLogger(__name__)


def _polling_enabled() -> bool:
    return os.getenv("ENABLE_REDEMPTION_POLLING", "true").lower() in ("1", "true", "yes")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler"""
    logger.info("Starting Matrix Provisioning Service...")

    # Instantiating the repository creates the SQLite schema, so a
    # misconfigured data volume fails at startup rather than on first request.
    container.get_repository()

    poller = None
    if _polling_enabled():
        poller = container.get_redemption_poller()
        poller.start()
    else:
        logger.info("Redemption polling disabled by configuration")

    logger.info("Matrix Provisioning Service started successfully")

    yield

    logger.info("Shutting down Matrix Provisioning Service...")
    if poller is not None:
        await poller.stop()
    logger.info("Matrix Provisioning Service shutdown complete")


app = FastAPI(
    title="Matrix Provisioning Service",
    description=(
        "Provisions Lotti sync accounts on a Synapse homeserver and tracks the "
        "lifecycle of the bundles that grant access to them."
    ),
    version="0.1.0",
    lifespan=lifespan,
)

cors_origins_str = os.getenv("CORS_ALLOWED_ORIGINS", "http://localhost:5174")
cors_origins = [origin.strip() for origin in cors_origins_str.split(",") if origin.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["Content-Type", "Authorization"],
)

# Everything except the client rotation callback is an admin operation:
# provisioning accounts, reading the roster and purging history all require an
# admin key. `/bundles/{id}/rotated` is deliberately left on the regular key so
# the Lotti client can confirm rotation without holding admin credentials.
app.add_middleware(
    APIKeyAuthMiddleware,
    admin_path_prefixes=[
        "/api/v1/bundles",
        "/api/v1/stats",
        "/api/v1/purges",
    ],
)

app.include_router(router, prefix="/api/v1")


@app.get("/health", tags=["health"])
async def health() -> dict:
    """Liveness probe.

    Registered at the app root rather than under ``/api/v1`` because the auth
    middleware exempts the literal path ``/health``.
    """
    return {"status": "ok", "service": "matrix-provisioning-service"}


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "8003"))
    uvicorn.run(app, host="0.0.0.0", port=port)  # nosec B104
