"""Main FastAPI application for Gemma Local Service."""

import asyncio
import base64
import json
import logging
import os
import time
import uuid
from typing import Optional, List, Dict, Any, AsyncGenerator, Union, cast
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, HTTPException, BackgroundTasks, Request
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


class ChatCompletionRequest(BaseModel):
    """Request model for chat completion (OpenAI-compatible) with audio support."""
    model: str
    messages: List[Dict[str, Any]]
    temperature: float = 0.7
    max_tokens: Optional[int] = 2000
    top_p: float = 0.95
    stream: bool = False
    presence_penalty: float = 0.0
    frequency_penalty: float = 0.0
    # Audio transcription support
    audio: Optional[str] = Field(None, description="Base64-encoded audio data for transcription")
    language: Optional[str] = Field(None, description="Language hint for audio transcription")


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
async def startup_event() -> None:
    """Initialize service on startup."""
    logger.info(f"Starting Gemma Local Service with model: {ServiceConfig.MODEL_ID}")
    logger.info(f"Device: {ServiceConfig.DEFAULT_DEVICE}")
    logger.info(f"Model variant: {ServiceConfig.MODEL_VARIANT}")
    
    # Check if model is available
    if model_manager.is_model_available():
        logger.info("Model files found. Ready to load on first request.")
    else:
        logger.info("Model not downloaded. Use /v1/models/pull to download.")


# Health check
@app.get("/health")
async def health_check() -> Dict[str, Any]:
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



@app.post("/v1/chat/completions", response_model=None)
async def chat_completion(request: ChatCompletionRequest):
    """
    Unified OpenAI-compatible chat completion endpoint.
    
    Supports both text generation and audio transcription through chat interface.
    When audio data is provided, performs context-aware transcription.
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
        
        # Check if this is audio transcription or regular chat
        if request.audio:
            # Audio transcription through chat completions
            logger.info("Processing audio transcription via chat completions")
            
            # Extract context from messages
            context_prompt = None
            for message in request.messages:
                if message.get('role') == 'user' and 'Context:' in message.get('content', ''):
                    # Extract context from user message
                    content = message.get('content', '')
                    if 'Context:' in content:
                        context_part = content.split('Context:')[1].split('\n\n')[0].strip()
                        if context_part:
                            context_prompt = context_part
                    break
            
            # Process audio - disable chunking to match working script behavior
            result = await audio_processor.process_audio_base64(
                request.audio,
                context_prompt,
                use_chunking=False  # Disable chunking to avoid "Run Run" issue
            )
            
            # Handle both single audio and chunked audio
            if isinstance(result[0], list):
                # Multiple chunks - shouldn't happen with use_chunking=False
                audio_chunks, combined_prompt = result
            else:
                # Single audio array - expected path
                audio_array, combined_prompt = result
                audio_chunks = [audio_array]
            
            # Add language hint if provided
            if request.language:
                combined_prompt = f"{combined_prompt}\n\nLanguage: {request.language}"
            
            # Build chat-style messages for context-aware transcription
            messages = [
                {"role": "system", "content": "You are a helpful assistant that transcribes audio accurately. Format the transcription clearly with proper punctuation and paragraph breaks. If there are multiple speakers, indicate speaker changes. Remove filler words. Focus on the context provided."},
                {"role": "user", "content": combined_prompt}
            ]
            
            # Generate transcription using chat context
            if len(audio_chunks) == 1:
                transcription = await generate_transcription_with_chat_context(
                    messages=messages,
                    audio_array=audio_chunks[0],
                    temperature=request.temperature
                )
            else:
                # Multi-chunk processing with context
                transcription = await process_audio_chunks_with_continuation(
                    chunks=audio_chunks,
                    initial_messages=messages,
                    temperature=request.temperature
                )
            
            # Return in chat completion format
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
                            "content": transcription
                        },
                        "finish_reason": "stop"
                    }
                ],
                "usage": {
                    "prompt_tokens": len(combined_prompt.split()) if combined_prompt else 0,
                    "completion_tokens": len(transcription.split()) if transcription else 0,
                    "total_tokens": len(combined_prompt.split()) + len(transcription.split()) if combined_prompt and transcription else 0
                }
            }
        
        else:
            # Regular text chat completion
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


@app.post("/v1/models/pull", response_model=None)
async def pull_model(request: ModelPullRequest):
    """
    Download and prepare model with progress streaming.
    """
    async def generate():
        """Generator that yields SSE-formatted download progress."""
        try:
            # Send initial status
            progress_event = {
                "status": "pulling",
                "digest": ServiceConfig.MODEL_ID,
                "total": None,
                "completed": 0
            }
            yield f"data: {json.dumps(progress_event)}\n\n"
            
            # Check if already cached
            if model_manager.is_model_available():
                progress_event = {
                    "status": "success",
                    "digest": ServiceConfig.MODEL_ID,
                    "message": "Model already downloaded"
                }
                yield f"data: {json.dumps(progress_event)}\n\n"
                return
            
            # Download model files
            logger.info(f"Starting model download: {ServiceConfig.MODEL_ID}")
            
            try:
                # Simulate download progress
                from huggingface_hub import snapshot_download
                
                def progress_callback(downloaded, total):
                    if total > 0:
                        progress = int((downloaded / total) * 100)
                        progress_event = {
                            "status": "pulling",
                            "digest": ServiceConfig.MODEL_ID,
                            "total": total,
                            "completed": downloaded,
                            "percent": progress
                        }
                        # Note: This is simplified - actual implementation would need async handling
                
                # Get HuggingFace token
                hf_token = os.environ.get('HF_TOKEN') or os.environ.get('HUGGING_FACE_HUB_TOKEN')

                # Download model to the correct location
                model_path = snapshot_download(
                    repo_id=ServiceConfig.MODEL_ID,
                    cache_dir=ServiceConfig.CACHE_DIR / "models",
                    local_dir=ServiceConfig.get_model_path(),
                    local_dir_use_symlinks=False,
                    resume_download=True,
                    token=hf_token
                )
                
                # Send success message
                progress_event = {
                    "status": "success", 
                    "digest": ServiceConfig.MODEL_ID,
                    "message": f"Model downloaded successfully to {model_path}"
                }
                yield f"data: {json.dumps(progress_event)}\n\n"
                
            except Exception as e:
                error_event = {
                    "status": "error",
                    "error": str(e)
                }
                yield f"data: {json.dumps(error_event)}\n\n"
                
        except Exception as e:
            logger.error(f"Model pull error: {e}")
            error_event = {
                "status": "error",
                "error": str(e)
            }
            yield f"data: {json.dumps(error_event)}\n\n"
    
    if request.stream:
        return StreamingResponse(generate(), media_type="text/event-stream")
    else:
        # Non-streaming download
        try:
            if model_manager.is_model_available():
                return {"status": "success", "message": "Model already downloaded"}
            
            from huggingface_hub import snapshot_download

            # Get HuggingFace token
            hf_token = os.environ.get('HF_TOKEN') or os.environ.get('HUGGING_FACE_HUB_TOKEN')

            model_path = snapshot_download(
                repo_id=ServiceConfig.MODEL_ID,
                cache_dir=ServiceConfig.CACHE_DIR / "models",
                local_dir=ServiceConfig.get_model_path(),
                local_dir_use_symlinks=False,
                resume_download=True,
                token=hf_token
            )
            
            return {
                "status": "success",
                "message": f"Model downloaded to {model_path}"
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))


@app.get("/v1/models", response_model=None)
async def list_models():
    """List available models (OpenAI-compatible)."""
    models = []
    
    # Add current model if available
    if model_manager.is_model_available():
        models.append(ModelInfo(
            id=ServiceConfig.MODEL_ID,
            object="model",
            created=int(time.time()),
            owned_by="local",
            capabilities={
                "chat": True,
                "audio": True,
                "transcription": True,
                "streaming": True
            },
            size_gb=ServiceConfig.MODEL_SIZE_GB.get(ServiceConfig.MODEL_VARIANT, None)
        ).dict())
    
    return {
        "object": "list",
        "data": models
    }


@app.post("/v1/models/load")
async def load_model(background_tasks: BackgroundTasks):
    """
    Explicitly load model into memory.
    """
    try:
        if model_manager.is_model_loaded():
            return {
                "status": "already_loaded",
                "message": f"Model {ServiceConfig.MODEL_ID} is already loaded",
                "device": model_manager.device
            }
        
        if not model_manager.is_model_available():
            raise HTTPException(
                status_code=404,
                detail="Model not downloaded. Use /v1/models/pull to download first."
            )
        
        # Load model in background
        background_tasks.add_task(model_manager.load_model)
        
        return {
            "status": "loading",
            "message": f"Loading model {ServiceConfig.MODEL_ID}...",
            "device": model_manager.device
        }
    
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
def build_chat_prompt(messages: List[Dict[str, Any]], include_audio_token: bool = True) -> str:
    """Build a prompt from chat messages with audio token support."""
    prompt_parts = []

    for message in messages:
        role = message.get("role", "user")
        content = message.get("content", "")

        if role == "system":
            prompt_parts.append(f"System: {content}")
        elif role == "user":
            # Add audio token placeholder for Gemma 3N
            if include_audio_token and "audio" in content.lower():
                # Insert special audio token that Gemma 3N expects
                prompt_parts.append(f"User: <audio>\n{content}")
            else:
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
        # Ensure model is loaded
        if not model_manager.is_model_loaded():
            logger.error("Model not loaded for chunk processing!")
            await model_manager.load_model()
            if not model_manager.is_model_loaded():
                raise Exception("Failed to load model for chunk processing")

        logger.info(f"Audio array shape: {audio_array.shape}, dtype: {audio_array.dtype}")

        # Convert audio to float32 and ensure it's in the correct format
        import numpy as np

        # Ensure audio is float32 (Gemma 3N expects this)
        if audio_array.dtype != np.float32:
            audio_array = audio_array.astype(np.float32)

        # Ensure audio is 1D
        if audio_array.ndim == 2:
            # If stereo, average both channels to create mono
            audio_array = np.mean(audio_array, axis=0)
        elif audio_array.ndim > 2:
            # Flatten multi-dimensional arrays
            audio_array = audio_array.flatten()

        # Ensure it's 1D with proper shape
        audio_array = np.squeeze(audio_array)
        if audio_array.ndim != 1:
            audio_array = audio_array.flatten()

        # Normalize audio to [-1, 1] range as expected by Gemma 3N
        max_val = np.abs(audio_array).max()
        if max_val > 1.0:
            audio_array = audio_array / max_val
        elif max_val == 0:
            # Handle silent audio
            logger.warning("Audio appears to be silent (all zeros)")

        # Ensure audio is not empty
        if len(audio_array) == 0:
            raise ValueError("Audio array is empty after preprocessing")

        logger.info(f"Processed audio shape: {audio_array.shape}, dtype: {audio_array.dtype}, range: [{audio_array.min():.2f}, {audio_array.max():.2f}]")

        # Use Lotti-style structured prompting for better transcription
        # Create message structure with audio content matching Lotti's approach
        formatted_messages = [
            {
                "role": "user",
                "content": [
                    {"type": "audio", "audio": audio_array},  # Pass numpy array directly
                    {"type": "text", "text": "Transcribe the audio."}
                ]
            }
        ]

        logger.info("Using apply_chat_template with structured messages")

        # Apply chat template to get proper inputs
        try:
            inputs = model_manager.processor.apply_chat_template(
                formatted_messages,
                add_generation_prompt=True,
                tokenize=True,
                return_dict=True,
                return_tensors="pt"
            )
            logger.info(f"✅ Chat template applied successfully")
            logger.info(f"Input keys: {inputs.keys()}")

        except Exception as template_error:
            logger.error(f"Chat template error: {template_error}")
            # Fallback to direct processor call if apply_chat_template fails
            logger.info("Falling back to direct processor call")

            inputs = model_manager.processor(
                text="Transcribe this audio",
                audio=audio_array,
                sampling_rate=ServiceConfig.AUDIO_SAMPLE_RATE,
                return_tensors="pt"
            )
        
        # Move inputs to device
        inputs = {k: v.to(model_manager.device) if hasattr(v, 'to') else v for k, v in inputs.items()}
        
        # Get optimized generation config for transcription
        gen_config = ServiceConfig.get_generation_config("transcription")
        gen_config.update({
            'pad_token_id': model_manager.tokenizer.pad_token_id or model_manager.tokenizer.eos_token_id,
            'eos_token_id': model_manager.tokenizer.eos_token_id,
            'temperature': temperature if temperature > 0 else 0.1,
        })
        
        # Use appropriate inference mode based on device
        try:
            if model_manager.device == "cpu":
                with torch.inference_mode():
                    outputs = model_manager.model.generate(**inputs, **gen_config)
            else:  # mps or cuda
                with torch.no_grad():
                    outputs = model_manager.model.generate(**inputs, **gen_config)
        except Exception as e:
            logger.error(f"Generation failed on {model_manager.device}: {e}")
            # Fallback to simpler generation
            outputs = model_manager.model.generate(
                **inputs,
                max_new_tokens=2000,
                do_sample=False,
                pad_token_id=model_manager.tokenizer.eos_token_id
            )
        
        # Decode the output, skipping the input tokens
        input_length = inputs['input_ids'].shape[1] if 'input_ids' in inputs else 0
        response = model_manager.tokenizer.decode(
            outputs[0][input_length:],
            skip_special_tokens=True
        )

        transcription = response.strip()

        # Whisper-like output cleaning - remove redundancy but keep full content
        def clean_whisper_style(text: str) -> str:
            """Clean transcription output to remove redundancy but preserve all content."""
            # If text contains "Transcription:" markers, it means multiple attempts
            if 'Transcription:' in text:
                parts = text.split('Transcription:')
                if len(parts) > 1:
                    # Take the first actual transcription part
                    text = parts[1].split('Text Transcription:')[0]
                    text = text.split('\n')[0]  # Take first line of that part

            # Stop at indicators that the model is adding meta-commentary
            stop_indicators = [
                'Speaker change',
                'No fillers present',
                'Clear formatting',
                'This is a transcription',
                'The transcription is',
                'Here is the transcription',
                "I'm sorry",
                "I apologize",
                "Please provide"
            ]

            for indicator in stop_indicators:
                if indicator in text:
                    text = text.split(indicator)[0]

            # Remove common prefixes only if they exist
            prefixes_to_remove = [
                "Transcription: ",
                "Text: ",
                "Audio: "
            ]
            for prefix in prefixes_to_remove:
                if text.startswith(prefix):
                    text = text[len(prefix):]

            return text.strip()

        transcription = clean_whisper_style(transcription)

        # Final safety check for reasonable length
        max_reasonable_length = 2000  # ~1000 words max for 2-minute audio
        if len(transcription) > max_reasonable_length:
            transcription = transcription[:max_reasonable_length].strip()
            logger.info(f"Truncated to reasonable length: {max_reasonable_length} chars")

        logger.info(f"Final transcription result length: {len(transcription)} chars")
        logger.info(f"Final transcription preview: {transcription[:200]}...")

        return transcription
    
    except Exception as e:
        logger.error(f"Chat-context transcription error: {e}")
        logger.error(f"Full traceback:", exc_info=True)
        raise


async def process_audio_chunks_with_continuation(
    chunks: List[np.ndarray],
    initial_messages: List[Dict[str, Any]],
    temperature: float
) -> str:
    """
    Process multiple audio chunks with smart continuation.
    Each chunk gets the previous transcription as context to continue from.
    """
    transcriptions = []
    previous_text = ""
    
    logger.info(f"Processing {len(chunks)} audio chunks with continuation context")

    # Process all chunks for full transcription
    chunks_to_process = chunks
    logger.info(f"Processing all {len(chunks_to_process)} chunks for complete transcription")

    # Log chunk durations for debugging
    for i, chunk in enumerate(chunks_to_process):
        chunk_duration = len(chunk) / 16000  # assuming 16kHz sample rate
        logger.info(f"Chunk {i+1}: {chunk_duration:.1f}s ({len(chunk)} samples)")
    
    for i, chunk in enumerate(chunks_to_process):
        try:
            logger.info(f"Processing chunk {i+1}/{len(chunks_to_process)}")
            
            # Use simple prompt for all chunks
            chunk_messages = [
                {"role": "system", "content": "You are a helpful assistant that transcribes audio accurately."},
                {"role": "user", "content": "Transcribe this audio:"}
            ]

            transcription = await generate_transcription_with_chat_context(
                messages=chunk_messages,
                audio_array=chunk,
                temperature=temperature
            )
            
            # Clean up transcription
            cleaned = transcription.strip()
            
            # Remove any duplicate text from the beginning that might overlap with previous
            if i > 0 and previous_text:
                # Check for overlap at the boundary (last 50 chars of previous with first 50 of current)
                overlap_window = min(50, len(previous_text), len(cleaned))
                if overlap_window > 10:
                    last_prev = previous_text[-overlap_window:].lower()
                    first_curr = cleaned[:overlap_window].lower()
                    
                    # Find overlap
                    for j in range(overlap_window, 10, -1):
                        if last_prev[-j:] == first_curr[:j]:
                            # Remove the overlapping part from current
                            cleaned = cleaned[j:].strip()
                            logger.info(f"Removed {j} overlapping characters from chunk {i+1}")
                            break
            
            if cleaned:
                transcriptions.append(cleaned)
                previous_text = " ".join(transcriptions)  # Update context with all text so far
                logger.info(f"Chunk {i+1} transcribed: {cleaned[:100]}...")
        
        except Exception as e:
            logger.error(f"Failed to process chunk {i+1}: {e}")
            logger.error(f"Chunk {i+1} error details:", exc_info=True)
            # Add placeholder to maintain chunk order
            transcriptions.append(f"[Chunk {i+1} failed to process]")
            # Continue with other chunks but don't update previous_text
    
    # Join all transcriptions with proper spacing
    final_transcription = " ".join(transcriptions)
    
    # Final cleanup - remove any remaining artifacts
    final_transcription = final_transcription.replace('---|', '').replace('|---', '')
    final_transcription = final_transcription.replace('Previous transcription:', '')
    final_transcription = final_transcription.replace('Continue transcribing:', '')
    
    return final_transcription


async def process_audio_chunks_with_context(
    chunks: List[np.ndarray],
    messages: List[Dict[str, Any]],
    temperature: float
) -> str:
    """Legacy function - redirects to continuation-based processing."""
    return await process_audio_chunks_with_continuation(chunks, messages, temperature)


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