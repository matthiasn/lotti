"""Main FastAPI application for Qwen Image Service."""

import base64
import json
import logging
import os
import sys
import time
import uuid
from contextlib import asynccontextmanager
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Any, Dict, Optional, Union

import torch
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

# Load environment variables
env_path = Path(__file__).parent / ".env"
if env_path.exists():
    load_dotenv(env_path)

from config import ServiceConfig
from image_generator import ImageGenerator
from model_manager import model_manager

# Configure logging
logging.basicConfig(
    level=getattr(logging, ServiceConfig.LOG_LEVEL),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

try:
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, ServiceConfig.LOG_LEVEL))

    log_file = ServiceConfig.LOG_DIR / "service.log"
    file_handler = RotatingFileHandler(log_file, maxBytes=5 * 1024 * 1024, backupCount=3)
    file_handler.setLevel(getattr(logging, ServiceConfig.LOG_LEVEL))
    fmt = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
    file_handler.setFormatter(fmt)
    if not any(isinstance(h, RotatingFileHandler) for h in root_logger.handlers):
        root_logger.addHandler(file_handler)

    if os.getenv("LOG_TO_STDOUT", "0").lower() in ("1", "true", "yes", "on"):
        if not any(
            isinstance(h, logging.StreamHandler) and getattr(h, "stream", None) is sys.stdout
            for h in root_logger.handlers
        ):
            sh = logging.StreamHandler(sys.stdout)
            sh.setLevel(getattr(logging, ServiceConfig.LOG_LEVEL))
            sh.setFormatter(fmt)
            root_logger.addHandler(sh)
except Exception as _e:
    logging.getLogger(__name__).warning(f"Failed to initialize log handlers: {_e}")

logger = logging.getLogger(__name__)

# Create image generator
image_generator = ImageGenerator(model_manager)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup/shutdown events."""
    # Startup
    logger.info(f"Starting Qwen Image Service with model: {ServiceConfig.MODEL_ID}")
    logger.info(f"Device: {ServiceConfig.DEFAULT_DEVICE}")
    logger.info(f"Torch version: {torch.__version__}; dtype: {ServiceConfig.TORCH_DTYPE}")
    logger.info(
        f"Default image size: {ServiceConfig.DEFAULT_WIDTH}x{ServiceConfig.DEFAULT_HEIGHT}"
    )

    if model_manager.is_model_available():
        logger.info("Model files found. Ready to load on first request.")
    else:
        logger.info("Model not downloaded. Use /v1/models/pull to download.")

    yield
    # Shutdown
    await model_manager.unload_model()


# Create FastAPI app
app = FastAPI(
    title="Qwen Image Service",
    description="Local Qwen Image model service for text-to-image generation",
    version="1.0.0",
    lifespan=lifespan,
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request/Response models
class ImageGenerationRequest(BaseModel):
    """Request model for image generation."""

    prompt: str = Field(..., description="Text description of the image to generate")
    negative_prompt: str = Field("", description="Text describing what to avoid")
    width: Optional[int] = Field(None, description="Image width in pixels")
    height: Optional[int] = Field(None, description="Image height in pixels")
    num_inference_steps: Optional[int] = Field(None, description="Number of diffusion steps")
    cfg_scale: Optional[float] = Field(None, description="Classifier-free guidance scale")
    seed: Optional[int] = Field(None, description="Random seed for reproducibility")


class ModelPullRequest(BaseModel):
    """Request model for model download."""

    model_name: str = "Qwen/Qwen-Image"
    stream: bool = True


class ModelInfo(BaseModel):
    """Model information response."""

    id: str
    object: str = "model"
    created: int
    owned_by: str = "local"
    capabilities: Dict[str, bool]
    size_gb: Optional[float] = None


# Health check
@app.get("/health")
async def health_check() -> Dict[str, Any]:
    """Health check endpoint."""
    return {
        "status": "healthy",
        "model_available": model_manager.is_model_available(),
        "model_loaded": model_manager.is_model_loaded(),
        "device": model_manager.device,
        "default_dimensions": f"{ServiceConfig.DEFAULT_WIDTH}x{ServiceConfig.DEFAULT_HEIGHT}",
    }


# Image generation endpoint
@app.post("/v1/images/generate")
async def generate_image(request: ImageGenerationRequest) -> Dict[str, Any]:
    """
    Generate an image from a text prompt.

    Returns a JSON response with base64-encoded PNG image data.
    """
    try:
        req_id = uuid.uuid4().hex[:8]
        logger.info(f"[REQ {req_id}] Image generation request received")

        if not request.prompt or not request.prompt.strip():
            raise HTTPException(status_code=400, detail="Prompt cannot be empty")

        # Validate dimensions if provided
        width = request.width or ServiceConfig.DEFAULT_WIDTH
        height = request.height or ServiceConfig.DEFAULT_HEIGHT
        if not ServiceConfig.validate_dimensions(width, height):
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Dimensions {width}x{height} out of range "
                    f"({ServiceConfig.MIN_DIMENSION}-{ServiceConfig.MAX_DIMENSION})"
                ),
            )

        # Ensure model is loaded
        if not model_manager.is_model_loaded():
            if not model_manager.is_model_available():
                raise HTTPException(
                    status_code=404,
                    detail="Model not downloaded. Use /v1/models/pull to download.",
                )
            logger.info(f"[REQ {req_id}] Loading model...")
            success = await model_manager.load_model()
            if not success:
                raise HTTPException(status_code=500, detail="Failed to load model")

        # Generate the image
        result = await image_generator.generate(
            prompt=request.prompt,
            negative_prompt=request.negative_prompt,
            width=request.width,
            height=request.height,
            num_inference_steps=request.num_inference_steps,
            cfg_scale=request.cfg_scale,
            seed=request.seed,
            request_id=req_id,
        )

        # Convert to base64 PNG
        image_bytes = ImageGenerator.image_to_png_bytes(result["image"])
        image_base64 = base64.b64encode(image_bytes).decode()

        logger.info(
            f"[REQ {req_id}] Image generated: {len(image_bytes)} bytes, "
            f"seed={result['seed']}, time={result['generation_time']:.2f}s"
        )

        return {
            "data": [
                {
                    "b64_json": image_base64,
                    "mime_type": "image/png",
                }
            ],
            "model": ServiceConfig.MODEL_ID,
            "seed": result["seed"],
            "generation_time": result["generation_time"],
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Image generation error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# Model management endpoints
@app.post("/v1/models/pull", response_model=None)
async def pull_model(
    request: ModelPullRequest,
) -> Union[StreamingResponse, Dict[str, Any]]:
    """Download model from HuggingFace."""
    # Validate requested model matches configured model
    configured_model = ServiceConfig.MODEL_ID
    if request.model_name != configured_model:
        raise HTTPException(
            status_code=400,
            detail=f"Requested model '{request.model_name}' does not match "
            f"configured model '{configured_model}'. "
            f"Set QWEN_IMAGE_MODEL_ID environment variable to change the model.",
        )

    async def generate() -> Any:
        try:
            model_id = request.model_name

            yield f"data: {json.dumps({'status': 'pulling', 'digest': model_id})}\n\n"

            if model_manager.is_model_available():
                yield f"data: {json.dumps({'status': 'success', 'message': 'Model already downloaded'})}\n\n"
                return

            logger.info(f"Starting model download: {model_id}")

            async for progress in model_manager.download_model():
                yield f"data: {json.dumps(progress)}\n\n"

        except Exception as e:
            logger.error(f"Model pull error: {e}")
            yield f"data: {json.dumps({'status': 'error', 'error': str(e)})}\n\n"

    if request.stream:
        return StreamingResponse(generate(), media_type="text/event-stream")
    else:
        try:
            if model_manager.is_model_available():
                return {"status": "success", "message": "Model already downloaded"}

            async for _ in model_manager.download_model():
                pass

            return {"status": "success", "message": "Model downloaded"}
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))


@app.get("/v1/models")
async def list_models() -> Dict[str, Any]:
    """List available models."""
    models = []

    if model_manager.is_model_available():
        models.append(
            ModelInfo(
                id=ServiceConfig.MODEL_ID,
                object="model",
                created=int(time.time()),
                owned_by="local",
                capabilities={
                    "text_to_image": True,
                    "image_editing": False,
                },
            ).model_dump()
        )

    return {"object": "list", "data": models}


@app.post("/v1/models/load")
async def load_model() -> Dict[str, Any]:
    """Explicitly load model into memory."""
    try:
        if model_manager.is_model_loaded():
            return {
                "status": "already_loaded",
                "message": f"Model {ServiceConfig.MODEL_ID} is already loaded",
                "device": model_manager.device,
            }

        if not model_manager.is_model_available():
            raise HTTPException(
                status_code=404,
                detail="Model not downloaded. Use /v1/models/pull first.",
            )

        success = await model_manager.load_model()
        if not success:
            raise HTTPException(status_code=500, detail="Failed to load model")

        return {
            "status": "loaded",
            "message": f"Model {ServiceConfig.MODEL_ID} loaded",
            "device": model_manager.device,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Model load error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host=ServiceConfig.DEFAULT_HOST,
        port=ServiceConfig.DEFAULT_PORT,
        log_level=ServiceConfig.LOG_LEVEL.lower(),
    )
