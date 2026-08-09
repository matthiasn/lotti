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


def _enabled(name: str, default: str = "true") -> bool:
    return os.getenv(name, default).lower() in ("1", "true", "yes")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler"""
    logger.info("Starting Matrix Provisioning Service...")

    # Instantiating the repository creates the SQLite schema, so a
    # misconfigured data volume fails at startup rather than on first request.
    container.get_repository()

    poller = None
    if _enabled("ENABLE_REDEMPTION_POLLING"):
        poller = container.get_redemption_poller()
        poller.start()
    else:
        logger.info("Redemption polling disabled by configuration")

    # On by default and destructive, so it is logged loudly enough that an
    # operator reading startup output cannot miss that data will be deleted.
    scheduler = None
    if _enabled("ENABLE_RETENTION_SWEEP"):
        scheduler = container.get_retention_scheduler()
        scheduler.start()
        logger.warning(
            "Retention sweep is ENABLED — room history and media older than the "
            "retention window will be deleted on a schedule. Set "
            "ENABLE_RETENTION_SWEEP=false to disable, or mark individual users "
            "retention_exempt."
        )
    else:
        logger.info("Retention sweep disabled by configuration")

    logger.info("Matrix Provisioning Service started successfully")

    yield

    logger.info("Shutting down Matrix Provisioning Service...")
    if poller is not None:
        await poller.stop()
    if scheduler is not None:
        await scheduler.stop()
    # After the background loops, so nothing is mid-request when the shared
    # connection pool goes away.
    await container.get_admin_client().aclose()
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

# Ordering matters, and is the reverse of how it reads: `add_middleware`
# prepends, so the *last* one added is the outermost. Auth is registered first
# and CORS second so CORS wraps it — a preflight OPTIONS carries no
# Authorization header, and with auth on the outside every cross-origin request
# would 401 at the preflight and CORS_ALLOWED_ORIGINS could never work.
#
# Everything under /api/v1 is an admin operation — provisioning accounts,
# reading the roster, purging history — so admin is the default and only the
# client callback namespace is exempted. Stated this way round, a route added
# later is protected unless someone deliberately opens it.
app.add_middleware(
    APIKeyAuthMiddleware,
    client_path_prefixes=["/api/v1/client"],
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["Content-Type", "Authorization"],
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
