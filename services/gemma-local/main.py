"""Main FastAPI application for Gemma Local Service."""

import asyncio
import base64
import json
import logging
import time
import uuid
from typing import Optional, List, Dict, Any, AsyncGenerator, Union
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, HTTPException, UploadFile, File, Form, BackgroundTasks, Request
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import torch
import numpy as np

# Load environment variables from .env file if it exists
from dotenv import load_dotenv
env_path = Path(__file__).parent / '.env'
if env_path.exists():
    load_dotenv(env_path)
    logging.info(f"Loaded environment from {env_path}")

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
def normalize_model_name(model_name: str) -> str:
    """Normalize model names to handle legacy naming conventions."""
    # Handle legacy model names
    model_mapping = {
        "gemma-2-2b-it": "google/gemma-2b-it",
        "gemma-2-9b-it": "google/gemma-2b-it",  # Map to available model
        "gemma-3n-E2B-it": "google/gemma-3n-E2B-it",
        "gemma-3n-E4B-it": "google/gemma-3n-E4B-it",
    }
    return model_mapping.get(model_name, model_name)


@app.post("/v1/audio/transcriptions")
async def transcribe_audio(
    request: Request,
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
    
    When context (prompt) is provided, uses chat completions for context-aware transcription.
    """
    
    # Check if this is a JSON request (from the Dart client)
    content_type = request.headers.get("content-type", "")
    if content_type.startswith("application/json"):
        try:
            json_body = await request.json()
            
            # Extract parameters from JSON body
            audio = json_body.get("audio")
            model = normalize_model_name(json_body.get("model", "gemma-2b"))
            prompt = json_body.get("prompt")
            response_format = json_body.get("response_format", "json")
            temperature = json_body.get("temperature", 0.7)
            language = json_body.get("language")
            stream = json_body.get("stream", False)
            
        except Exception as e:
            logger.error(f"Failed to parse JSON body: {e}")
            raise HTTPException(status_code=400, detail="Invalid JSON body")
    else:
        # Normalize model name for form requests too
        model = normalize_model_name(model)
    
    
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
        
        # Process audio with context (now supports chunking)
        
        try:
            # TESTING: Disable chunking completely for better coherence
            use_chunking = False
            logger.info(f"Audio processing: use_chunking={use_chunking} (disabled for testing)")
            
            result = await audio_processor.process_audio_base64(
                audio_base64,
                prompt,
                use_chunking=use_chunking
            )
        except Exception as e:
            logger.error(f"Audio processing failed: {type(e).__name__}: {e}")
            logger.error(f"Full traceback:", exc_info=True)
            raise
        
        # Handle both single audio and chunked audio
        if isinstance(result[0], list):
            # Multiple chunks - THIS SHOULD NOT HAPPEN with use_chunking=False
            audio_chunks, combined_prompt = result
            logger.warning(f"UNEXPECTED: Got {len(result[0])} chunks despite use_chunking=False!")
        else:
            # Single audio array - EXPECTED path
            audio_array, combined_prompt = result
            audio_chunks = [audio_array]
            logger.info(f"SUCCESS: Got single audio array, duration={len(audio_array)/16000:.1f}s")
        
        # Add language hint if provided
        if language:
            combined_prompt = f"{combined_prompt}\n\nLanguage: {language}"
        
        # Log the full prompt for debugging when context is provided
        if prompt:
            logger.info("=" * 60)
            logger.info("TRANSCRIPTION WITH CONTEXT - Using Chat Completions")
            logger.info(f"Original context/prompt: {prompt}")
            logger.info(f"Combined prompt being sent to model: {combined_prompt}")
            logger.info("=" * 60)
        
        # Generate transcription
        # Use chat completions approach when context is provided for better results
        use_chat_completions = bool(prompt and prompt.strip())
        
        if use_chat_completions:
            # Build chat-style messages for context-aware transcription
            messages = [
                {"role": "system", "content": "You are a helpful assistant that transcribes audio accurately. Format the transcription clearly with proper punctuation and paragraph breaks. If there are multiple speakers, indicate speaker changes. Remove filler words. Focus on the context provided."},
                {"role": "user", "content": combined_prompt}
            ]
            
            logger.info("Using CHAT COMPLETIONS endpoint for context-aware transcription")
            
            # Process through chat completions for better context handling
            # Flutter now sends stream: false for better compatibility
            if stream:
                # Streaming is still supported but not used by Flutter for transcription
                logger.warning("Streaming transcription with context requested - using fallback")
                # Fall back to regular streaming without context for now
                generator = StreamGenerator(
                    model_manager=model_manager,
                    audio_processor=audio_processor
                )
                
                return StreamingResponse(
                    generator.generate_stream(
                        prompt=combined_prompt,
                        audio_array=audio_chunks[0] if len(audio_chunks) == 1 else audio_chunks,
                        temperature=temperature,
                        max_tokens=ServiceConfig.DEFAULT_MAX_TOKENS
                    ),
                    media_type="text/event-stream"
                )
            else:
                # Non-streaming chat completion (now the default for Flutter)
                logger.info("Processing non-streaming transcription with chat context")
                
                # For audio transcription through chat, we need to pass audio to the model
                # We'll use a hybrid approach
                if len(audio_chunks) == 1:
                    transcription = await generate_transcription_with_chat_context(
                        messages=messages,
                        audio_array=audio_chunks[0],
                        temperature=temperature
                    )
                else:
                    # Multi-chunk processing with context
                    transcription = await process_audio_chunks_with_context(
                        chunks=audio_chunks,
                        messages=messages,
                        temperature=temperature
                    )
        else:
            # Original transcription logic without context
            if stream:
                # Streaming response
                generator = StreamGenerator(
                    model_manager=model_manager,
                    audio_processor=audio_processor
                )
                
                return StreamingResponse(
                    generator.generate_stream(
                        prompt=combined_prompt,
                        audio_array=audio_chunks[0] if len(audio_chunks) == 1 else audio_chunks,
                        temperature=temperature,
                        max_tokens=ServiceConfig.DEFAULT_MAX_TOKENS
                    ),
                    media_type="text/event-stream"
                )
            else:
                # Non-streaming response
                if len(audio_chunks) == 1:
                    # Single chunk processing
                    transcription = await generate_transcription_optimized(
                        prompt=combined_prompt,
                        audio_array=audio_chunks[0],
                        temperature=temperature
                    )
                else:
                    # Multi-chunk processing
                    transcription = await process_audio_chunks(
                        chunks=audio_chunks,
                        prompt=combined_prompt,
                        temperature=temperature
                    )
        
        # Calculate total duration for response (MOVED OUTSIDE THE ELSE BLOCK)
        total_duration = sum(len(chunk) for chunk in audio_chunks) / audio_processor.sample_rate
        
        # Log the transcription result for debugging
        logger.info("=" * 60)
        logger.info(f"TRANSCRIPTION RESULT:")
        logger.info(f"Text: {transcription}")
        logger.info(f"Audio duration: {total_duration:.2f} seconds")
        logger.info(f"Used chat completions: {use_chat_completions}")
        logger.info("=" * 60)
        
        # Format response based on response_format
        if response_format == "text":
            return transcription
        elif response_format == "verbose_json":
            response = TranscriptionResponse(
                text=transcription,
                language=language,
                duration=total_duration
            )
            return response
        else:  # json
            response = {"text": transcription}
            logger.info(f"Returning JSON response: {response}")
            # Return JSONResponse to ensure proper content-type and immediate flush
            return JSONResponse(content=response)
    
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
                    # Sanitize error information before sending to client
                    sanitized_progress = progress.copy()
                    if "error" in sanitized_progress:
                        sanitized_progress["error"] = "Model download failed."
                    if sanitized_progress.get("status", "").startswith("Error:"):
                        sanitized_progress["status"] = "Error: Model download failed."
                    yield f"data: {json.dumps(sanitized_progress)}\n\n"
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
            
            # Sanitize final status before returning to client
            if final_status and "error" in final_status:
                final_status = final_status.copy()
                final_status["error"] = "Model download failed."
                if final_status.get("status", "").startswith("Error:"):
                    final_status["status"] = "Error: Model download failed."
            
            return final_status
    
    except Exception as e:
        logger.error(f"Model pull error: {e}")
        logger.error(f"Full traceback:", exc_info=True)
        raise HTTPException(status_code=500, detail="Model download failed.")


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


# Legacy function for backwards compatibility
async def generate_transcription(
    prompt: str,
    audio_array: np.ndarray,
    temperature: float
) -> str:
    """Legacy generate_transcription function - use generate_transcription_optimized instead."""
    return await generate_transcription_optimized(prompt, audio_array, temperature)


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


async def generate_transcription_optimized(
    prompt: str,
    audio_array: np.ndarray,
    temperature: float,
    task_type: str = "cpu_optimized"
) -> str:
    """Generate transcription from audio."""
    
    try:
        # Use the processor to handle both audio and text together
        
        # Reshape audio to add batch dimension if needed
        if audio_array.ndim == 1:
            audio_array = audio_array.reshape(1, -1)
        
        # Process audio and text through the unified processor
        inputs = model_manager.processor(
            audio=audio_array,
            text=prompt,
            sampling_rate=ServiceConfig.AUDIO_SAMPLE_RATE,
            return_tensors="pt"
        )
        
        # Move inputs to device
        inputs = {k: v.to(model_manager.device) if hasattr(v, 'to') else v for k, v in inputs.items()}
        
        # Get optimized generation config for the task
        gen_config = ServiceConfig.get_generation_config(task_type)
        gen_config.update({
            'pad_token_id': model_manager.tokenizer.pad_token_id or model_manager.tokenizer.eos_token_id,
            'eos_token_id': model_manager.tokenizer.eos_token_id,
            'temperature': temperature if temperature > 0 else 0.1,
        })
        
        
        # Use inference mode for better CPU performance
        if model_manager.device == "cpu":
            with torch.inference_mode():
                outputs = model_manager.model.generate(**inputs, **gen_config)
        else:
            with torch.no_grad():
                outputs = model_manager.model.generate(**inputs, **gen_config)
        
        # Check if generation succeeded
        if outputs is None or len(outputs) == 0:
            logger.error("Model generation failed - no outputs produced")
            raise ValueError("Model generation failed - no outputs produced")
        
        # Decode
        # Decode the output, skipping the input tokens
        input_length = inputs['input_ids'].shape[1] if 'input_ids' in inputs else 0
        response = model_manager.tokenizer.decode(
            outputs[0][input_length:],
            skip_special_tokens=True
        )
        
        return response.strip()
    
    except Exception as e:
        logger.error(f"=== GENERATION ERROR ===")
        logger.error(f"Error type: {type(e).__name__}")
        logger.error(f"Error message: {e}")
        logger.error(f"Full traceback:", exc_info=True)
        raise


async def process_audio_chunks(
    chunks: List[np.ndarray],
    prompt: str,
    temperature: float
) -> str:
    """Process multiple audio chunks and combine transcriptions."""
    
    transcriptions = []
    for i, chunk in enumerate(chunks):
        
        try:
            # Use shorter prompt for chunks after the first
            chunk_prompt = prompt if i == 0 else "Transcribe the following audio chunk:"
            
            transcription = await generate_transcription_optimized(
                prompt=chunk_prompt,
                audio_array=chunk,
                temperature=temperature,
                task_type="cpu_optimized"
            )
            
            if transcription.strip():
                transcriptions.append(transcription.strip())
            
        except Exception as e:
            logger.warning(f"Failed to process chunk {i+1}: {e}")
            # Continue with other chunks
    
    # Combine transcriptions with proper spacing
    final_transcription = " ".join(transcriptions)
    
    return final_transcription


async def generate_transcription_with_chat_context(
    messages: List[Dict[str, Any]],
    audio_array: np.ndarray,
    temperature: float
) -> str:
    """Generate transcription using chat context for better understanding."""
    try:
        # Build chat prompt from messages
        chat_prompt = build_chat_prompt(messages)
        
        logger.info(f"Chat-based transcription prompt: {chat_prompt[:200]}...")
        
        # Reshape audio to add batch dimension if needed
        if audio_array.ndim == 1:
            audio_array = audio_array.reshape(1, -1)
        
        # Process audio and text through the unified processor
        inputs = model_manager.processor(
            audio=audio_array,
            text=chat_prompt,
            sampling_rate=ServiceConfig.AUDIO_SAMPLE_RATE,
            return_tensors="pt"
        )
        
        # Move inputs to device
        inputs = {k: v.to(model_manager.device) if hasattr(v, 'to') else v for k, v in inputs.items()}
        
        # Get optimized generation config
        gen_config = ServiceConfig.get_generation_config("cpu_optimized")
        gen_config.update({
            'pad_token_id': model_manager.tokenizer.pad_token_id or model_manager.tokenizer.eos_token_id,
            'eos_token_id': model_manager.tokenizer.eos_token_id,
            'temperature': temperature if temperature > 0 else 0.1,
        })
        
        # Use inference mode for better performance
        if model_manager.device == "cpu":
            with torch.inference_mode():
                outputs = model_manager.model.generate(**inputs, **gen_config)
        else:
            with torch.no_grad():
                outputs = model_manager.model.generate(**inputs, **gen_config)
        
        # Decode the output, skipping the input tokens
        input_length = inputs['input_ids'].shape[1] if 'input_ids' in inputs else 0
        response = model_manager.tokenizer.decode(
            outputs[0][input_length:],
            skip_special_tokens=True
        )
        
        transcription = response.strip()
        logger.info(f"Chat-based transcription result: {transcription}")
        
        return transcription
    
    except Exception as e:
        logger.error(f"Chat-context transcription error: {e}")
        logger.error(f"Full traceback:", exc_info=True)
        raise


async def process_audio_chunks_with_context(
    chunks: List[np.ndarray],
    messages: List[Dict[str, Any]],
    temperature: float
) -> str:
    """Process multiple audio chunks with chat context."""
    transcriptions = []
    
    logger.info(f"Processing {len(chunks)} audio chunks with context")
    
    for i, chunk in enumerate(chunks):
        try:
            logger.info(f"Processing chunk {i+1}/{len(chunks)}")
            
            # For chunks after the first, use simpler prompt
            if i > 0:
                # Simpler continuation message without including previous text
                chunk_messages = [
                    {"role": "system", "content": "You are a helpful assistant that transcribes audio accurately."},
                    {"role": "user", "content": "Transcribe this audio segment:"}
                ]
            else:
                chunk_messages = messages
            
            transcription = await generate_transcription_with_chat_context(
                messages=chunk_messages,
                audio_array=chunk,
                temperature=temperature
            )
            
            # Clean up transcription to avoid repetition markers
            cleaned = transcription.strip()
            # Remove repetition markers like ---|---|---
            cleaned = cleaned.replace('---|', '').replace('|---', '')
            
            if cleaned and not cleaned.startswith('Previous transcription:'):
                transcriptions.append(cleaned)
                logger.info(f"Chunk {i+1} transcribed: {cleaned[:100]}...")
        
        except Exception as e:
            logger.warning(f"Failed to process chunk {i+1} with context: {e}")
    
    return " ".join(transcriptions)


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