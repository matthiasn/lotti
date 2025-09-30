"""New modular FastAPI application"""

import logging
import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from dotenv import load_dotenv

# Import constants first - needed for configuration
from .core.constants import (
    API_TITLE,
    API_DESCRIPTION,
    API_VERSION,
    ENV_FILE_NAME,
    ENV_LOG_LEVEL,
    DEFAULT_LOG_LEVEL,
    LOG_FORMAT,
    CORS_ALLOW_ORIGINS,
    CORS_ALLOW_METHODS,
    CORS_ALLOW_HEADERS,
    MSG_LOADED_ENV,
    MSG_STARTING_SERVICE,
    MSG_MODEL_FILES_FOUND,
    MSG_MODEL_NOT_DOWNLOADED,
)

# Load environment variables
env_path = Path(__file__).parent.parent / ENV_FILE_NAME
if env_path.exists():
    load_dotenv(env_path)
    logging.info(f"{MSG_LOADED_ENV} {env_path}")

# Configure logging
logging.basicConfig(level=getattr(logging, os.environ.get(ENV_LOG_LEVEL, DEFAULT_LOG_LEVEL)), format=LOG_FORMAT)
logger = logging.getLogger(__name__)

# Import services after logging is configured
from .container import container  # noqa: E402 - Import after logging setup
from .api.routes import router  # noqa: E402 - Import after logging setup


def create_app() -> FastAPI:
    """Create and configure the FastAPI application"""

    # Validate configuration
    config_manager = container.get_config_manager()
    config_manager.validate_config()

    # Create FastAPI app
    app = FastAPI(
        title=API_TITLE,
        description=API_DESCRIPTION,
        version=API_VERSION,
    )

    # Add CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=CORS_ALLOW_ORIGINS,
        allow_credentials=True,
        allow_methods=CORS_ALLOW_METHODS,
        allow_headers=CORS_ALLOW_HEADERS,
    )

    # Include routes
    app.include_router(router)

    # Startup event
    @app.on_event("startup")
    async def startup_event() -> None:
        """Initialize service on startup"""
        model_manager = container.get_model_manager()
        model_info = model_manager.get_model_info()

        logger.info(f"{MSG_STARTING_SERVICE}: {model_info.id}")
        logger.info(f"Device: {model_info.device}")
        logger.info(f"Model variant: {model_info.variant}")

        if model_manager.is_model_available():
            logger.info(MSG_MODEL_FILES_FOUND)
        else:
            logger.info(MSG_MODEL_NOT_DOWNLOADED)

    return app


# Create the app instance
app = create_app()


if __name__ == "__main__":
    config_manager = container.get_config_manager()
    uvicorn.run(
        "src.main_new:app",
        host=config_manager.get_host(),
        port=config_manager.get_port(),
        log_level=config_manager.get_log_level().lower(),
        reload=True,
    )
