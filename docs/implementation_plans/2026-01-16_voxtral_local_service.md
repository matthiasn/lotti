# Implementation Plan: Voxtral Local Transcription Service

## Executive Summary

Build a new local transcription service using Mistral AI's Voxtral model as a swap/replacement for the existing Gemma 3N service. The service will follow the same architectural patterns as `services/gemma-local/` and provide an OpenAI-compatible API.

## Research Findings

### Voxtral Model Variants

| Model | Parameters | VRAM Required | Use Case |
|-------|-----------|---------------|----------|
| Voxtral Mini 3B | 3B | ~9.5 GB (bf16/fp16) | Local/edge deployment |
| Voxtral Small 24B | 24B | ~55 GB (bf16/fp16) | Production/multi-GPU |

### Key Technical Details

- **License**: Apache 2.0 (fully open source)
- **HuggingFace Token**: NOT required - models are publicly available without gating
- **Audio Duration**: Up to 30 minutes for transcription, 40 minutes for understanding
- **Context Window**: 32k tokens
- **Languages**: English, Spanish, French, Portuguese, Hindi, German, Dutch, Italian, Arabic (auto-detection)
- **Supported Formats**: MP3, WAV, M4A, FLAC, OGG, WebM

### Recommendation: Start with Voxtral Mini 3B

**Rationale:**
1. Fits on typical consumer hardware (RTX 3090/4090 with 24GB, Apple Silicon with 16GB+)
2. Designed specifically for local/edge deployment
3. Still achieves state-of-the-art performance per Mistral benchmarks
4. Can upgrade to 24B later if needed with same API

## Existing Code to Reuse

### From `services/gemma-local/`
| File | Reusability | Notes |
|------|-------------|-------|
| `main.py` | High | FastAPI structure, endpoints, request models |
| `config.py` | High | Device detection, generation config patterns |
| `model_manager.py` | Medium | Model loading patterns, memory management |
| `audio_processor.py` | High | Audio chunking, preprocessing |
| `streaming.py` | High | SSE streaming implementation |

### From `whisper_server/`
| File | Reusability | Notes |
|------|-------------|-------|
| `whisper_api_server.py` | Medium | OpenAI transcription endpoint pattern |

### From Flutter Client
| File | Reusability | Notes |
|------|-------------|-------|
| `gemma3n_inference_repository.dart` | High | Template for `voxtral_inference_repository.dart` |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (Lotti)                       │
├─────────────────────────────────────────────────────────────┤
│              VoxtralInferenceRepository                      │
│     (lib/features/ai/repository/voxtral_inference_...)       │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTP (OpenAI-compatible)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Voxtral Local Service                           │
│                services/voxtral-local/                       │
├─────────────────────────────────────────────────────────────┤
│  main.py          │ FastAPI endpoints                        │
│  config.py        │ Device/model configuration               │
│  model_manager.py │ Model loading, switching, memory mgmt    │
│  audio_processor.py │ Audio preprocessing, chunking          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Voxtral Mini 3B (or vLLM server)                │
│         HuggingFace: mistralai/Voxtral-Mini-3B-2507          │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Steps

### Phase 1: Service Skeleton
1. Create `services/voxtral-local/` directory structure
2. Copy and adapt `config.py` from gemma-local with Voxtral-specific settings
3. Create `requirements.txt` with dependencies
4. Set up basic FastAPI app with health endpoint

### Phase 2: Model Management
1. Implement `VoxtralModelManager` class in `model_manager.py`
2. Add model download via HuggingFace Hub (no token needed)
3. Implement device detection (CUDA > MPS > CPU)
4. Add memory pressure monitoring and cleanup

### Phase 3: Inference Implementation
1. Implement Voxtral inference using `VoxtralForConditionalGeneration`
2. Add audio preprocessing with `AutoProcessor`
3. Create transcription generation pipeline
4. Test with sample audio files

### Phase 4: API Endpoints
1. Implement `/v1/audio/transcriptions` (OpenAI-compatible)
2. Implement `/v1/chat/completions` with audio support
3. Add `/v1/models/pull` for model download
4. Add `/health` and `/v1/models` endpoints

### Phase 5: Flutter Integration
1. Create `VoxtralInferenceRepository` based on Gemma3n pattern
2. Add Voxtral option to AI settings UI
3. Wire up transcription feature to use Voxtral
4. Add model download UI (similar to Gemma 3N)

### Phase 6: Testing & Documentation
1. Write service tests
2. Test on various hardware (CUDA, MPS, CPU)
3. Performance benchmarking vs Whisper
4. Update service README

### Phase 7: vLLM Integration (Performance Optimization)

**Rationale**: vLLM provides substantial throughput gains over raw Transformers inference. For longer audio (e.g., 30-minute meeting transcriptions), this translates to dramatically reduced wait times.

#### 7.1 vLLM Server Setup
1. Add `vllm_server.py` - wrapper to start vLLM serve process
2. Add configuration options for vLLM vs Transformers backend selection
3. Implement health checks for vLLM server process

#### 7.2 vLLM Serve Command
```bash
vllm serve mistralai/Voxtral-Mini-3B-2507 \
  --tokenizer_mode mistral \
  --config_format mistral \
  --load_format mistral \
  --port 11345
```

#### 7.3 Client Adaptation
1. Update `model_manager.py` to support both backends
2. Add `VOXTRAL_BACKEND` config option: `transformers` (default) or `vllm`
3. When vLLM backend selected, route requests to vLLM's OpenAI-compatible API

#### 7.4 vLLM-Specific Features
- **Chunked prefill**: Better handling of long audio inputs
- **Prefix caching**: Faster repeated prompts
- **Continuous batching**: Better throughput for concurrent requests

#### 7.5 Files to Add for vLLM Support
```
services/voxtral-local/
├── vllm_server.py           # vLLM process manager
├── vllm_client.py           # Client for vLLM OpenAI API
└── start_vllm_server.sh     # Startup script for vLLM mode
```

#### 7.6 Performance Expectations
| Audio Duration | Transformers | vLLM (estimated) |
|----------------|--------------|------------------|
| 1 minute       | ~30s         | ~2-3s            |
| 5 minutes      | ~2.5min      | ~10-15s          |
| 30 minutes     | ~15min       | ~1-2min          |

*Note: Actual performance varies by hardware. vLLM requires CUDA; MPS support is limited.*

## Dependencies

### Python Service (`services/voxtral-local/requirements.txt`)
```
torch>=2.1.0
transformers>=4.45.0
mistral-common>=1.8.1
huggingface-hub>=0.19.0
fastapi>=0.100.0
uvicorn>=0.23.0
pydantic>=2.0.0
numpy>=1.24.0
librosa>=0.10.0
soundfile>=0.12.0
pydub>=0.25.1
psutil>=5.9.0
python-dotenv>=1.0.0
```

### Optional (for vLLM-based serving)
```
vllm[audio]>=0.6.0
```

## Configuration Defaults

```python
class VoxtralConfig:
    # Model settings
    MODEL_ID = "mistralai/Voxtral-Mini-3B-2507"

    # Audio settings
    AUDIO_SAMPLE_RATE = 16000
    MAX_AUDIO_DURATION_SECONDS = 1800  # 30 minutes
    AUDIO_CHUNK_SIZE_SECONDS = 60  # Voxtral handles longer chunks

    # API settings
    DEFAULT_PORT = 11344  # Different from Gemma (11343)
    DEFAULT_HOST = "127.0.0.1"

    # Generation
    DEFAULT_TEMPERATURE = 0.0  # Deterministic for transcription
    DEFAULT_MAX_TOKENS = 4096  # Higher for longer audio
```

## Key Differences from Gemma 3N Service

| Aspect | Gemma 3N | Voxtral |
|--------|----------|---------|
| Model loader | `AutoModelForImageTextToText` | `VoxtralForConditionalGeneration` |
| Processor | `AutoProcessor` | `AutoProcessor` (Voxtral-specific) |
| Max audio | 5 minutes (300s) | 30 minutes (1800s) |
| VRAM needed | ~6GB (E2B) / ~12GB (E4B) | ~9.5GB |
| HF token | Required (gated) | Not required |
| Languages | Limited | 9 languages + auto-detect |

## Verification Steps

1. **Unit tests**: Run `pytest services/voxtral-local/tests/`
2. **Manual test**: Start server, POST audio to `/v1/audio/transcriptions`
3. **Integration test**: Use Flutter app to transcribe audio with Voxtral
4. **Benchmark**: Compare transcription quality and speed vs Whisper

## Files to Create

```
services/voxtral-local/
├── main.py                    # FastAPI application
├── config.py                  # Configuration settings
├── model_manager.py           # Model loading and management
├── audio_processor.py         # Audio preprocessing
├── streaming.py               # SSE streaming support
├── requirements.txt           # Python dependencies
├── start_server.sh            # Startup script
├── .env.example               # Example environment file
├── README.md                  # Service documentation
└── tests/
    ├── __init__.py
    ├── test_config.py
    ├── test_model_manager.py
    └── test_endpoints.py

lib/features/ai/repository/
├── voxtral_inference_repository.dart  # Flutter client
```

## Design Decisions (Confirmed)

1. **Serving Approach**: Start with **Transformers**, then add **vLLM** for performance
   - Phase 1-6: Transformers backend (simpler, works on all platforms)
   - Phase 7: Add vLLM backend option for substantial performance gains
   - vLLM is critical for longer transcriptions (30-min meetings would take 15+ min with Transformers vs ~2 min with vLLM)
   - User can select backend via config: `VOXTRAL_BACKEND=transformers|vllm`

2. **Port allocation**: Use **11344** (next after Gemma's 11343)

3. **UI integration**: Add as **separate AI service option** alongside Gemma 3N in AI settings
   - Users explicitly choose Voxtral as their transcription service
   - Clear distinction from other AI services

4. **Hardware support**: **Both Apple Silicon (MPS) and NVIDIA (CUDA)**
   - Automatic device detection like existing services
   - CPU fallback for machines without GPU acceleration

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| 9.5GB VRAM too high for some users | Medium | Medium | CPU fallback, clear requirements in UI |
| Model download size (~18GB) | Low | Low | Progress indicator, resume support |
| Audio format compatibility | Low | Low | Reuse audio_processor.py from Gemma |
| API changes in transformers | Low | Medium | Pin version in requirements |

## Timeline Considerations

This plan focuses on implementation steps without time estimates. The phases can be executed sequentially, with Phase 1-3 being the core functionality and Phase 4-6 being integration and polish.

---

**Sources:**
- [Voxtral Official Announcement](https://mistral.ai/news/voxtral)
- [Voxtral Mini 3B on HuggingFace](https://huggingface.co/mistralai/Voxtral-Mini-3B-2507)
- [Voxtral Small 24B on HuggingFace](https://huggingface.co/mistralai/Voxtral-Small-24B-2507)
- [Voxtral Transformers Documentation](https://huggingface.co/docs/transformers/main/model_doc/voxtral)
