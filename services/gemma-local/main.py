"""Main FastAPI application for Gemma Local Service."""

import asyncio
import base64
import json
import logging
import time
import uuid
from typing import Optional, List, Dict, Any, AsyncGenerator
from datetime import datetime

from fastapi import FastAPI, HTTPException, UploadFile, File, Form, BackgroundTasks
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import torch
import numpy as np

from config import ServiceConfig
from model_manager import model_manager
from audio_processor import audio_processor
from streaming import StreamGenerator

# Configure logging
logging.basicConfig(
    level=getattr(logging, ServiceConfig.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Gemma Local Service",
    description="Local Gemma model service with OpenAI-compatible API",
    version="1.0.0"
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
class TranscriptionRequest(BaseModel):
    """Request model for audio transcription."""
    audio: Optional[str] = Field(None, description="Base64-encoded audio data")
    file: Optional[UploadFile] = Field(None, description="Audio file upload")
    model: str = Field("gemma-2b", description="Model to use")
    prompt: Optional[str] = Field(None, description="Context prompt for transcription")
    response_format: str = Field("json", description="Response format (json, text, verbose_json)")
    temperature: float = Field(0.7, ge=0.0, le=2.0)
    language: Optional[str] = Field(None, description="Language hint for transcription")
    stream: bool = Field(False, description="Enable streaming response")


class TranscriptionResponse(BaseModel):
    """Response model for audio transcription."""
    text: str
    language: Optional[str] = None
    duration: Optional[float] = None
    segments: Optional[List[Dict[str, Any]]] = None


class ChatCompletionRequest(BaseModel):
    """Request model for chat completion (OpenAI-compatible)."""
    model: str
    messages: List[Dict[str, Any]]
    temperature: float = 0.7
    max_tokens: Optional[int] = 1000
    top_p: float = 0.95
    stream: bool = False
    presence_penalty: float = 0.0
    frequency_penalty: float = 0.0


class ModelPullRequest(BaseModel):
    """Request model for model download."""
    model_name: str
    stream: bool = True


class ModelInfo(BaseModel):
    """Model information response."""
    id: str
    object: str = "model"
    created: int
    owned_by: str = "local"
    capabilities: Dict[str, bool]
    size_gb: Optional[float] = None


# Startup event
@app.on_event("startup")
async def startup_event():
    """Initialize service on startup."""
    logger.info("Starting Gemma Local Service...")
    
    # Check if model is available
    if model_manager.is_model_available():
        logger.info("Model files found. Ready to load on first request.")
    else:
        logger.info("Model not downloaded. Use /v1/models/pull to download.")


# Health check
@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "model_available": model_manager.is_model_available(),
        "model_loaded": model_manager.is_model_loaded(),
        "device": model_manager.device
    }


# OpenAI-compatible endpoints
@app.post("/v1/audio/transcriptions")
async def transcribe_audio(
    file: Optional[UploadFile] = File(None),
    audio: Optional[str] = Form(None),
    model: str = Form("gemma-2b"),
    prompt: Optional[str] = Form(None),
    response_format: str = Form("json"),
    temperature: float = Form(0.7),
    language: Optional[str] = Form(None),
    stream: bool = Form(False)
):
    """
    OpenAI-compatible audio transcription endpoint.
    
    Accepts either:
    - file: Audio file upload
    - audio: Base64-encoded audio data
    """
    try:
        # Ensure model is loaded
        if not model_manager.is_model_loaded():
            if not model_manager.is_model_available():
                raise HTTPException(
                    status_code=404,
                    detail="Model not downloaded. Use /v1/models/pull to download."
                )
            
            logger.info("Loading model for transcription...")
            success = await model_manager.load_model()
            if not success:
                raise HTTPException(
                    status_code=500,
                    detail="Failed to load model"
                )
        
        # Process audio
        if file:
            # Read file content
            audio_bytes = await file.read()
            audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        elif audio:
            audio_base64 = audio
        else:
            raise HTTPException(
                status_code=400,
                detail="Either 'file' or 'audio' must be provided"
            )
        
        # Process audio with context
        audio_array, combined_prompt = await audio_processor.process_audio_base64(
            audio_base64,
            prompt
        )
        
        # Add language hint if provided
        if language:
            combined_prompt = f"{combined_prompt}\n\nLanguage: {language}"
        
        # Generate transcription
        if stream:
            # Streaming response
            generator = StreamGenerator(
                model_manager=model_manager,
                audio_processor=audio_processor
            )
            
            return StreamingResponse(
                generator.generate_stream(
                    prompt=combined_prompt,
                    audio_array=audio_array,
                    temperature=temperature,
                    max_tokens=ServiceConfig.DEFAULT_MAX_TOKENS
                ),
                media_type="text/event-stream"
            )
        else:
            # Non-streaming response
            transcription = await generate_transcription(
                prompt=combined_prompt,
                audio_array=audio_array,
                temperature=temperature
            )
            
            # Format response based on response_format
            if response_format == "text":
                return transcription
            elif response_format == "verbose_json":
                return TranscriptionResponse(
                    text=transcription,
                    language=language,
                    duration=len(audio_array) / audio_processor.sample_rate
                )
            else:  # json
                return {"text": transcription}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Transcription error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/v1/chat/completions")
async def chat_completion(request: ChatCompletionRequest):
    """
    OpenAI-compatible chat completion endpoint.
    
    Supports text generation with optional streaming.
    """
    try:
        # Ensure model is loaded
        if not model_manager.is_model_loaded():
            if not model_manager.is_model_available():
                raise HTTPException(
                    status_code=404,
                    detail="Model not downloaded. Use /v1/models/pull to download."
                )
            
            logger.info("Loading model for chat completion...")
            success = await model_manager.load_model()
            if not success:
                raise HTTPException(
                    status_code=500,
                    detail="Failed to load model"
                )
        
        # Build prompt from messages
        prompt = build_chat_prompt(request.messages)
        
        if request.stream:
            # Streaming response
            generator = StreamGenerator(
                model_manager=model_manager,
                audio_processor=audio_processor
            )
            
            return StreamingResponse(
                generator.generate_chat_stream(
                    prompt=prompt,
                    temperature=request.temperature,
                    max_tokens=request.max_tokens or ServiceConfig.DEFAULT_MAX_TOKENS,
                    top_p=request.top_p
                ),
                media_type="text/event-stream"
            )
        else:
            # Non-streaming response
            response_text = await generate_text(
                prompt=prompt,
                temperature=request.temperature,
                max_tokens=request.max_tokens or ServiceConfig.DEFAULT_MAX_TOKENS,
                top_p=request.top_p
            )
            
            return {
                "id": f"chatcmpl-{uuid.uuid4().hex[:8]}",
                "object": "chat.completion",
                "created": int(time.time()),
                "model": request.model,
                "choices": [
                    {
                        "index": 0,
                        "message": {
                            "role": "assistant",
                            "content": response_text
                        },
                        "finish_reason": "stop"
                    }
                ],
                "usage": {
                    "prompt_tokens": len(prompt.split()),
                    "completion_tokens": len(response_text.split()),
                    "total_tokens": len(prompt.split()) + len(response_text.split())
                }
            }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Chat completion error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/v1/models/pull")
async def pull_model(request: ModelPullRequest):
    """
    Download and prepare model with progress streaming.
    
    Similar to Ollama's model pull endpoint.
    """
    try:
        if request.stream:
            # Streaming progress updates
            async def generate():
                async for progress in model_manager.download_model():
                    yield f"data: {json.dumps(progress)}\n\n"
                yield "data: [DONE]\n\n"
            
            return StreamingResponse(
                generate(),
                media_type="text/event-stream"
            )
        else:
            # Non-streaming (wait for completion)
            final_status = None
            async for progress in model_manager.download_model():
                final_status = progress
            
            return final_status
    
    except Exception as e:
        logger.error(f"Model pull error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/v1/models")
async def list_models():
    """List available models and their status."""
    model_info = await model_manager.get_model_info()
    
    return {
        "object": "list",
        "data": [
            ModelInfo(
                id=model_info["model_id"],
                created=int(time.time()),
                capabilities={
                    "transcription": True,
                    "chat": True,
                    "multimodal": model_info.get("supports_multimodal", False),
                    "streaming": True
                },
                size_gb=model_info.get("size_gb")
            )
        ]
    }


@app.delete("/v1/models/{model_name}")
async def delete_model(model_name: str):
    """Remove model from local storage."""
    try:
        # Unload model from memory
        await model_manager.unload_model()
        
        # TODO: Implement file deletion
        # For now, just unload from memory
        
        return {"message": f"Model {model_name} unloaded from memory"}
    
    except Exception as e:
        logger.error(f"Model deletion error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/v1/models/load")
async def load_model(background_tasks: BackgroundTasks):
    """Load model into memory (warm-up)."""
    try:
        if model_manager.is_model_loaded():
            return {"message": "Model already loaded"}
        
        if not model_manager.is_model_available():
            raise HTTPException(
                status_code=404,
                detail="Model not downloaded. Use /v1/models/pull to download."
            )
        
        # Load model in background
        background_tasks.add_task(model_manager.load_model)
        
        return {"message": "Model loading started"}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Model load error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# Helper functions
def build_chat_prompt(messages: List[Dict[str, Any]]) -> str:
    """Build a prompt from chat messages."""
    prompt_parts = []
    
    for message in messages:
        role = message.get("role", "user")
        content = message.get("content", "")
        
        if role == "system":
            prompt_parts.append(f"System: {content}")
        elif role == "user":
            prompt_parts.append(f"User: {content}")
        elif role == "assistant":
            prompt_parts.append(f"Assistant: {content}")
    
    # Add final prompt for assistant
    prompt_parts.append("Assistant:")
    
    return "\n\n".join(prompt_parts)


async def generate_transcription(
    prompt: str,
    audio_array: np.ndarray,
    temperature: float
) -> str:
    """Generate transcription from audio."""
    try:
        # Prepare inputs
        inputs = audio_processor.prepare_for_model(
            audio_array,
            model_manager.processor
        )
        
        # Add text prompt
        text_inputs = model_manager.tokenizer(
            prompt,
            return_tensors="pt",
            truncation=True,
            max_length=2048
        ).to(model_manager.device)
        
        # Generate
        with torch.no_grad():
            outputs = model_manager.model.generate(
                **text_inputs,
                max_new_tokens=ServiceConfig.DEFAULT_MAX_TOKENS,
                temperature=temperature,
                do_sample=temperature > 0,
                top_p=0.95,
                pad_token_id=model_manager.tokenizer.pad_token_id,
                eos_token_id=model_manager.tokenizer.eos_token_id,
            )
        
        # Decode
        response = model_manager.tokenizer.decode(
            outputs[0][text_inputs.input_ids.shape[1]:],
            skip_special_tokens=True
        )
        
        return response.strip()
    
    except Exception as e:
        logger.error(f"Generation error: {e}")
        raise


async def generate_text(
    prompt: str,
    temperature: float,
    max_tokens: int,
    top_p: float
) -> str:
    """Generate text completion."""
    try:
        # Tokenize input
        inputs = model_manager.tokenizer(
            prompt,
            return_tensors="pt",
            truncation=True,
            max_length=2048
        ).to(model_manager.device)
        
        # Generate
        with torch.no_grad():
            outputs = model_manager.model.generate(
                **inputs,
                max_new_tokens=max_tokens,
                temperature=temperature,
                do_sample=temperature > 0,
                top_p=top_p,
                pad_token_id=model_manager.tokenizer.pad_token_id,
                eos_token_id=model_manager.tokenizer.eos_token_id,
            )
        
        # Decode
        response = model_manager.tokenizer.decode(
            outputs[0][inputs.input_ids.shape[1]:],
            skip_special_tokens=True
        )
        
        return response.strip()
    
    except Exception as e:
        logger.error(f"Generation error: {e}")
        raise


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host=ServiceConfig.DEFAULT_HOST,
        port=ServiceConfig.DEFAULT_PORT,
        log_level=ServiceConfig.LOG_LEVEL.lower()
    )