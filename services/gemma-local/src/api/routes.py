"""API route definitions"""

import logging
from typing import Dict, Any
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse

from ..core.models import ChatRequest, DownloadProgress
from ..core.exceptions import ModelNotFoundError, TranscriptionError
from ..container import container

logger = logging.getLogger(__name__)

# Create router
router = APIRouter()


@router.get("/health")
async def health_check() -> Dict[str, Any]:
    """Health check endpoint"""
    model_manager = container.get_model_manager()
    return {
        "status": "healthy",
        "model_available": model_manager.is_model_available(),
        "model_loaded": model_manager.is_model_loaded(),
        "device": model_manager.device if hasattr(model_manager, 'device') else None
    }


@router.post("/v1/chat/completions", response_model=None)
async def chat_completion(request: ChatRequest):
    """
    Unified OpenAI-compatible chat completion endpoint.

    Supports both text generation and audio transcription through chat interface.
    """
    try:
        chat_service = container.get_chat_service()

        if request.stream:
            # Streaming response
            return StreamingResponse(
                chat_service.complete_chat_stream(request),
                media_type="text/event-stream"
            )
        else:
            # Non-streaming response
            response = await chat_service.complete_chat(request)
            return response.dict() if hasattr(response, 'dict') else response

    except ModelNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except TranscriptionError as e:
        raise HTTPException(status_code=500, detail=f"Transcription failed: {e}")
    except Exception as e:
        logger.error(f"Chat completion error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/v1/models/pull", response_model=None)
async def pull_model(request: Dict[str, Any]):
    """Download and prepare model with progress streaming"""

    async def generate():
        """Generator that yields SSE-formatted download progress"""
        try:
            model_downloader = container.get_model_downloader()
            config_manager = container.get_config_manager()
            model_manager = container.get_model_manager()

            model_name = request.get('model_name', '')
            stream = request.get('stream', True)

            async for progress in model_downloader.download_model(model_name, stream):
                import json
                progress_dict = {
                    "status": progress.status.value,
                    "message": progress.message,
                    "progress": progress.progress,
                    "total": progress.total_size,
                    "completed": progress.downloaded_size
                }
                if progress.error:
                    progress_dict["error"] = progress.error

                yield f"data: {json.dumps(progress_dict)}\n\n"

                # If download completed successfully, refresh model manager
                if progress.status.value == "complete":
                    if model_manager.is_model_loaded():
                        await model_manager.unload_model()
                    model_manager.refresh_config()

        except Exception as e:
            logger.error(f"Model pull error: {e}")
            import json
            error_event = {
                "status": "error",
                "error": str(e)
            }
            yield f"data: {json.dumps(error_event)}\n\n"

    if request.get('stream', True):
        return StreamingResponse(generate(), media_type="text/event-stream")
    else:
        # Non-streaming download
        try:
            model_downloader = container.get_model_downloader()
            model_name = request.get('model_name', '')

            # Collect all progress events
            result = None
            async for progress in model_downloader.download_model(model_name, False):
                if progress.status.value == "complete":
                    result = {
                        "status": "success",
                        "message": progress.message
                    }
                elif progress.status.value == "error":
                    raise HTTPException(status_code=500, detail=progress.error)

            return result or {"status": "success", "message": "Download completed"}

        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))


@router.get("/v1/models", response_model=None)
async def list_models():
    """List available models (OpenAI-compatible)"""
    model_manager = container.get_model_manager()
    model_validator = container.get_model_validator()
    config_manager = container.get_config_manager()

    models = []

    # Add currently configured model if available
    if model_manager.is_model_available():
        model_info = model_manager.get_model_info()
        models.append({
            "id": model_info.id,
            "object": "model",
            "created": 1234567890,  # Placeholder timestamp
            "owned_by": "local",
            "capabilities": {
                "chat": True,
                "audio": True,
                "transcription": True,
                "streaming": True
            }
        })

    # Add other available models
    try:
        available_models = model_validator.get_available_models()
        current_model = config_manager.get_model_id()

        for model_id in available_models:
            if model_id != current_model:
                models.append({
                    "id": model_id,
                    "object": "model",
                    "created": 1234567890,
                    "owned_by": "local",
                    "capabilities": {
                        "chat": True,
                        "audio": True,
                        "transcription": True,
                        "streaming": True
                    }
                })
    except Exception as e:
        logger.warning(f"Could not list available models: {e}")

    return {
        "object": "list",
        "data": models
    }


@router.post("/v1/models/load")
async def load_model():
    """Explicitly load model into memory"""
    try:
        model_manager = container.get_model_manager()

        if model_manager.is_model_loaded():
            model_info = model_manager.get_model_info()
            return {
                "status": "already_loaded",
                "message": f"Model {model_info.id} is already loaded",
                "device": model_info.device
            }

        if not model_manager.is_model_available():
            raise HTTPException(
                status_code=404,
                detail="Model not downloaded. Use /v1/models/pull to download first."
            )

        # Load model
        success = await model_manager.load_model()
        if not success:
            raise HTTPException(status_code=500, detail="Failed to load model")

        model_info = model_manager.get_model_info()
        return {
            "status": "loaded",
            "message": f"Model {model_info.id} loaded successfully",
            "device": model_info.device
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Model load error: {e}")
        raise HTTPException(status_code=500, detail=str(e))