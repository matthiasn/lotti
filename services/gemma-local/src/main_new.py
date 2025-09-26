"""New modular FastAPI application"""

import logging
import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# Load environment variables
from dotenv import load_dotenv
env_path = Path(__file__).parent.parent / '.env'
if env_path.exists():
    load_dotenv(env_path)
    logging.info(f"Loaded environment from {env_path}")

# Configure logging first
logging.basicConfig(
    level=getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Import after logging is configured
from .container import container
from .api.routes import router


def create_app() -> FastAPI:
    """Create and configure the FastAPI application"""

    # Validate configuration
    config_manager = container.get_config_manager()
    config_manager.validate_config()

    # Create FastAPI app
    app = FastAPI(
        title="Gemma Local Service",
        description="Local Gemma model service with OpenAI-compatible API - Modular Architecture",
        version="2.0.0"
    )

    # Add CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Include routes
    app.include_router(router)

    # Startup event
    @app.on_event("startup")
    async def startup_event():
        """Initialize service on startup"""
        model_manager = container.get_model_manager()
        model_info = model_manager.get_model_info()

        logger.info(f"Starting Gemma Local Service (Modular) with model: {model_info.id}")
        logger.info(f"Device: {model_info.device}")
        logger.info(f"Model variant: {model_info.variant}")

        if model_manager.is_model_available():
            logger.info("Model files found. Ready to load on first request.")
        else:
            logger.info("Model not downloaded. Use /v1/models/pull to download.")

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
        reload=True
    )