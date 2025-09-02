# Gemma Local Service

A local Python service that runs Google's Gemma models with multimodal support, providing OpenAI-compatible API endpoints for audio transcription and text generation.

## Features

- 🎙️ **Audio Transcription**: Transcribe audio with context-aware processing
- 💬 **Text Generation**: Generate text responses using Gemma models
- 🔄 **Streaming Support**: Real-time streaming responses for better UX
- 🔌 **OpenAI-Compatible**: Drop-in replacement for OpenAI/Gemini APIs
- 🏠 **Local Processing**: Complete privacy with on-device inference
- 📦 **Model Management**: Automatic model download and caching
- 🐳 **Docker Support**: Easy deployment with Docker containers

## Quick Start

### Using Docker (Recommended)

1. **Build and run the service:**
   ```bash
   cd services/gemma-local
   docker-compose up --build
   ```

2. **The service will be available at:** `http://localhost:8000`

3. **Check health status:**
   ```bash
   curl http://localhost:8000/health
   ```

### Local Development

1. **Install dependencies:**
   ```bash
   cd services/gemma-local
   pip install -r requirements.txt
   ```

2. **Run the service:**
   ```bash
   python main.py
   ```

3. **For development with auto-reload:**
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

## API Endpoints

### Health Check
```http
GET /health
```
Returns service health status and model availability.

### Audio Transcription
```http
POST /v1/audio/transcriptions
```

**Parameters:**
- `audio` (string): Base64-encoded audio data
- `file` (file): Audio file upload (alternative to base64)
- `model` (string): Model to use (default: "gemma-2b")
- `prompt` (string, optional): Context for better transcription
- `language` (string, optional): Language hint
- `temperature` (float): Generation temperature (0.0-2.0)
- `stream` (boolean): Enable streaming response

**Example:**
```python
import requests
import base64

# Read audio file
with open("audio.wav", "rb") as f:
    audio_base64 = base64.b64encode(f.read()).decode()

response = requests.post(
    "http://localhost:8000/v1/audio/transcriptions",
    data={
        "audio": audio_base64,
        "prompt": "This is a meeting about the Q4 budget",
        "model": "gemma-2b"
    }
)

print(response.json()["text"])
```

### Chat Completion
```http
POST /v1/chat/completions
```

**Request Body:**
```json
{
  "model": "gemma-2b",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant"},
    {"role": "user", "content": "Hello, how are you?"}
  ],
  "temperature": 0.7,
  "max_tokens": 1000,
  "stream": false
}
```

### Model Management

#### List Models
```http
GET /v1/models
```

#### Download Model
```http
POST /v1/models/pull
```
```json
{
  "model_name": "gemma-2b",
  "stream": true
}
```

#### Load Model into Memory
```http
POST /v1/models/load
```

#### Unload Model
```http
DELETE /v1/models/{model_name}
```

## Integration with Lotti

The service integrates seamlessly with Lotti's AI system through the `GemmaInferenceRepository`:

1. **Add Gemma as an inference provider in Lotti settings:**
   - Base URL: `http://localhost:8000`
   - Provider Type: Gemma
   - Model: gemma-2b (or your chosen model)

2. **Use for audio transcription:**
   ```dart
   final repository = GemmaInferenceRepository();
   final transcription = repository.transcribeAudio(
     audioBase64: audioData,
     model: "gemma-2b",
     contextPrompt: "Meeting notes about project planning",
     temperature: 0.7,
     provider: gemmaProvider,
   );
   ```

3. **The service supports:**
   - Context-aware transcription for better accuracy
   - Streaming responses for real-time feedback
   - Automatic model installation when needed
   - Progress tracking during model downloads

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GEMMA_MODEL_ID` | `google/gemma-2-2b-it` | Hugging Face model ID |
| `MAX_AUDIO_SIZE_MB` | `100` | Maximum audio file size |
| `MAX_CONCURRENT_REQUESTS` | `4` | Max concurrent requests |
| `REQUEST_TIMEOUT` | `300` | Request timeout in seconds |
| `LOG_LEVEL` | `INFO` | Logging level |
| `PORT` | `8000` | Service port |
| `HOST` | `0.0.0.0` | Service host |

### Supported Models

The service supports various Gemma model sizes:

- **gemma-2-2b-it**: 2B parameters, fastest, ~2GB memory
- **gemma-2-9b-it**: 9B parameters, balanced, ~9GB memory
- **gemma-3n-E2B-it**: Multimodal with 2B effective params
- **gemma-3n-E4B-it**: Multimodal with 4B effective params (best quality)

## Performance Optimization

### Memory Management
- Models are loaded on-demand and can be unloaded when not in use
- Supports 8-bit quantization for reduced memory usage
- Automatic garbage collection after model unloading

### Audio Processing
- Automatic resampling to 16kHz for optimal model performance
- Audio chunking for long recordings (>30 seconds)
- Normalization and DC offset removal for better quality

### Inference Optimization
- Model warm-up on first request for faster subsequent inference
- Batch processing support for multiple requests
- GPU acceleration when available (CUDA/MPS)

## Testing

Run the test suite:
```bash
cd services/gemma-local
pytest test_gemma_service.py -v
```

Run with coverage:
```bash
pytest test_gemma_service.py --cov=. --cov-report=html
```

## Troubleshooting

### Model Not Downloaded
If you see "Model not downloaded" errors:
1. Call `/v1/models/pull` endpoint to download the model
2. Monitor progress through the streaming response
3. Model will be cached for future use

### Out of Memory
If you encounter OOM errors:
1. Use a smaller model (e.g., gemma-2-2b instead of gemma-2-9b)
2. Enable 8-bit quantization (automatically enabled on GPU)
3. Increase Docker memory limits if using containers

### Slow Inference
For faster inference:
1. Use GPU acceleration (NVIDIA CUDA or Apple MPS)
2. Warm up the model with `/v1/models/load`
3. Use smaller models for real-time applications
4. Enable streaming for better perceived performance

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Lotti App                       │
└──────────────────┬──────────────────────────────┘
                   │ HTTP/REST
                   ▼
┌─────────────────────────────────────────────────┐
│           FastAPI Service Layer                  │
│  • OpenAI-compatible endpoints                   │
│  • Request validation                            │
│  • Streaming response handler                    │
└──────────────────┬──────────────────────────────┘
                   │
┌─────────────────────────────────────────────────┐
│           Model Management Layer                 │
│  • Hugging Face model downloads                  │
│  • Model loading/unloading                       │
│  • Memory optimization                           │
└──────────────────┬──────────────────────────────┘
                   │
┌─────────────────────────────────────────────────┐
│           Inference Engine                       │
│  • Transformers library                          │
│  • Audio processing (librosa/torchaudio)         │
│  • Token streaming                               │
└─────────────────────────────────────────────────┘
```

## Security Considerations

- **Local Processing**: All data is processed locally, never sent to external servers
- **No API Keys**: No authentication required for local deployment
- **Network Isolation**: Can run completely offline after model download
- **Data Privacy**: Audio and text data remain on your device

## Future Enhancements

- [ ] Support for more audio formats (currently: WAV, MP3, M4A, FLAC, OGG, WebM)
- [ ] Multi-language transcription with automatic language detection
- [ ] Fine-tuning support for domain-specific models
- [ ] WebSocket support for real-time streaming
- [ ] Batch transcription API for multiple files
- [ ] Speaker diarization for multi-speaker audio
- [ ] Integration with Whisper for comparison/fallback

## License

This service is part of the Lotti project and follows the same license terms.

## Contributing

Contributions are welcome! Please ensure:
1. All tests pass (`pytest`)
2. Code follows the existing style
3. Documentation is updated for new features
4. Docker build succeeds