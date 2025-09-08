# Gemma Local Service

A local Python service that runs Google's Gemma models with multimodal support, providing OpenAI-compatible API endpoints for audio transcription and text generation.

## Features

- 🎙️ **Audio Transcription**: Transcribe audio using multimodal Gemma models with context-aware processing
- 💬 **Text Generation**: Generate text responses using Gemma models
- 🔄 **Streaming Support**: Server-sent events (SSE) streaming for responses
- 🔌 **OpenAI-Compatible**: Drop-in replacement for OpenAI/Gemini APIs
- 🏠 **Local Processing**: Complete privacy with on-device inference
- 📦 **Model Management**: Automatic model download and caching
- 🔄 **Smart Device Selection**: Automatic CPU/GPU detection with memory-aware fallback
- 🐳 **Docker Support**: Easy deployment with Docker containers

## System Requirements

### Memory Requirements
- **Minimum RAM**: 16GB (for CPU inference)
- **Recommended RAM**: 32GB or more
- **GPU VRAM**: 11GB+ for GPU acceleration (model is ~10.13GB)

### Supported Platforms
- macOS (Intel/Apple Silicon with MPS support)
- Linux (with CUDA support for NVIDIA GPUs)
- Windows (CPU mode, CUDA for GPU)

## Prerequisites

Before running the Gemma service, you need to authenticate with Hugging Face to access the gated Gemma models:

1. **Create a Hugging Face account** at https://huggingface.co/join

2. **Accept the Gemma model agreement** at https://huggingface.co/google/gemma-3n-E2B-it
   - Click "Agree and access repository" on the model page

3. **Create an access token**:
   - Go to https://huggingface.co/settings/tokens
   - Click "New token"
   - Name it (e.g., "gemma-access")
   - Select "Read" permissions for public gated repos
   - Click "Generate"
   - **Copy the token** (starts with `hf_...`) - you'll need it in the next step

4. **Login via CLI:**
   ```bash
   pip install huggingface_hub
   huggingface-cli login
   # Paste your token when prompted (it won't display as you type)
   # Token format: hf_xxxxxxxxxxxxxxxxxxxxxxxxx
   ```
   The token will be saved locally for future use.

## Quick Start

### Automated Setup (Recommended)

Use the provided setup script for one-command installation:

```bash
cd services/gemma-local
HF_TOKEN=hf_your_token_here ./setup.sh
```

This script will:
- Authenticate with HuggingFace
- Create virtual environment
- Install all dependencies
- Create .env configuration
- Check system compatibility
- Provide next steps

### Using Docker

1. **Build and run the service:**
   ```bash
   cd services/gemma-local
   docker-compose up --build
   ```

2. **The service will be available at:** `http://localhost:11343`

3. **Check health status:**
   ```bash
   curl http://localhost:11343/health
   ```

### Local Development

1. **Create and activate virtual environment:**
   ```bash
   cd services/gemma-local
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Create configuration file (optional):**
   ```bash
   # Create .env file for custom settings
   cat > .env << EOF
   GEMMA_MODEL_ID=google/gemma-3n-E2B-it
   DEFAULT_DEVICE=auto
   USE_CPU_QUANTIZATION=false
   MAX_AUDIO_SIZE_MB=100
   LOG_LEVEL=INFO
   EOF
   ```

4. **Run the service:**
   ```bash
   python main.py
   ```
   The service will automatically download the model on first use (~10.13GB).

5. **For development with auto-reload:**
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 11343
   ```

## Configuration

### Environment Variables (.env file)

| Variable | Default | Description |
|----------|---------|-------------|
| `GEMMA_MODEL_ID` | `google/gemma-3n-E2B-it` | Hugging Face model ID |
| `DEFAULT_DEVICE` | `auto` | Device selection: `auto`, `cuda`, `mps`, or `cpu` |
| `USE_CPU_QUANTIZATION` | `false` | Enable 8-bit quantization on CPU |
| `MAX_AUDIO_SIZE_MB` | `100` | Maximum audio file size |
| `MAX_CONCURRENT_REQUESTS` | `4` | Max concurrent requests |
| `REQUEST_TIMEOUT` | `300` | Request timeout in seconds |
| `LOG_LEVEL` | `INFO` | Logging level |
| `PORT` | `11343` | Service port |
| `HOST` | `0.0.0.0` | Service host |

### Device Selection and Memory Management

The service automatically detects the best available device:

1. **GPU Priority** (if available):
   - NVIDIA GPUs via CUDA (Linux/Windows)
   - Apple Silicon via MPS (macOS)
   - Requires ~11GB VRAM for gemma-3n-E2B-it

2. **Automatic CPU Fallback**:
   - Triggers when GPU memory is insufficient
   - Uses system RAM instead of VRAM
   - Slower but works on any system with 16GB+ RAM

3. **Memory Requirements by Model**:
   - `gemma-3n-E2B-it`: ~10.13GB (multimodal, audio support)
   - `gemma-2b-it`: ~5GB (text-only, no audio support)

## API Endpoints

### Health Check
```http
GET /health
```
Returns service health status, model availability, and device information.

### Audio Transcription
```http
POST /v1/audio/transcriptions
```

**Parameters:**
- `audio` (string): Base64-encoded audio data
- `file` (file): Audio file upload (alternative to base64)
- `model` (string): Model to use (default: "gemma-3n-E2B-it")
- `prompt` (string, optional): Context for better transcription
- `language` (string, optional): Language hint
- `temperature` (float): Generation temperature (0.0-2.0)
- `stream` (boolean): Enable streaming response
- `response_format` (string): Output format (`json`, `text`, `verbose_json`)

**Example with cURL:**
```bash
# Transcribe audio file
curl -X POST http://localhost:11343/v1/audio/transcriptions \
  -F "file=@audio.wav" \
  -F "model=gemma-3n-E2B-it" \
  -F "prompt=This is a technical discussion" \
  -F "response_format=json"
```

**Example with Python:**
```python
import requests
import base64

# Read audio file
with open("audio.wav", "rb") as f:
    audio_base64 = base64.b64encode(f.read()).decode()

response = requests.post(
    "http://localhost:11343/v1/audio/transcriptions",
    json={
        "audio": audio_base64,
        "prompt": "This is a meeting about the Q4 budget",
        "model": "gemma-3n-E2B-it",
        "response_format": "json",
        "stream": False
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
  "model": "gemma-3n-E2B-it",
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
  "model_name": "gemma-3n-E2B-it",
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

## Integration with Lotti Flutter App

The service integrates seamlessly with Lotti's AI system through the `GemmaInferenceRepository`:

### 1. Configure in Lotti Settings

Add Gemma as an inference provider:
- **Base URL**: `http://localhost:11343`
- **Provider Type**: Gemma (local)
- **Model**: Select from available models:
  - `Gemma 3n E2B (Instruction Tuned)` - Multimodal with audio support (recommended)
  - `Gemma 2B (Instruction Tuned)` - Text-only, smaller footprint

### 2. Model Name Compatibility

The service automatically handles model name variations from Flutter:
- Flutter sends: `gemma-3n-E2B-it`
- Service maps to: `google/gemma-3n-E2B-it`

### 3. Usage in Flutter

```dart
final repository = GemmaInferenceRepository();
final transcription = await repository.transcribeAudio(
  audioBase64: audioData,
  model: "gemma-3n-E2B-it",
  contextPrompt: "Meeting notes about project planning",
  temperature: 0.7,
  provider: gemmaProvider,
);
```

## Performance Characteristics

### Streaming Implementation
- **Audio Transcription**: Pseudo-streaming (generates complete response, then streams)
- **Chat Completions**: True token-by-token streaming using background threads
- **SSE Format**: Server-sent events for compatibility with OpenAI clients

### Processing Speed
- **CPU Mode**: 
  - Inference runs synchronously on main thread
  - Uses `torch.inference_mode()` for optimization
  - Speed depends on CPU cores and model size
  
- **GPU Mode**:
  - Significantly faster inference (5-10x)
  - Requires sufficient VRAM (11GB+ for gemma-3n-E2B-it)
  - Automatic fallback to CPU if memory insufficient

### Audio Processing
- Automatic resampling to 16kHz for optimal model performance
- Audio chunking for recordings longer than 30 seconds
- Normalization and DC offset removal for better quality
- Maximum chunk size: 30 seconds per segment

## Supported Models

| Model | Parameters | Memory | Features | Use Case |
|-------|------------|--------|----------|----------|
| `google/gemma-3n-E2B-it` | 2B effective | ~10.13GB | Multimodal (audio + text) | Audio transcription, recommended |
| `google/gemma-3n-E4B-it` | 4B effective | ~15GB | Multimodal (audio + text) | Higher quality, needs more memory |
| `google/gemma-2b-it` | 2B | ~5GB | Text-only | Chat completions, no audio support |

**Note**: Despite the "2B" naming, the multimodal models are significantly larger due to audio processing components.

## Testing

Run the test suite:
```bash
cd services/gemma-local
pytest test_gemma_service.py -v
```

Test audio transcription:
```bash
python test_transcription.py
```

Run with coverage:
```bash
pytest test_gemma_service.py --cov=. --cov-report=html
```

## Troubleshooting

### Model Loading Issues

**"Failed to load model" Error:**
- Check available memory (16GB+ RAM for CPU, 11GB+ VRAM for GPU)
- Verify Hugging Face authentication
- Check internet connection for first-time download
- Review logs for specific error messages

### Memory and Performance

**Out of Memory (OOM) Errors:**
1. Service automatically falls back to CPU if GPU memory insufficient
2. For persistent issues:
   - Close other applications to free RAM
   - Use a smaller model if available
   - Enable CPU quantization in `.env` file
   - Increase Docker memory limits if using containers

**Slow Transcription:**
- CPU inference is 5-10x slower than GPU
- First request is slower (model loading)
- Consider:
  - Using GPU with sufficient VRAM
  - Pre-loading model with `/v1/models/load`
  - Enabling streaming for better perceived performance

### Common Issues

**Model Not Downloaded:**
```bash
# Manually trigger download
curl -X POST http://localhost:11343/v1/models/pull \
  -H "Content-Type: application/json" \
  -d '{"model_name": "gemma-3n-E2B-it", "stream": true}'
```

**Port Already in Use:**
```bash
# Check what's using port 11343
lsof -i :11343  # macOS/Linux
netstat -ano | findstr :11343  # Windows

# Use different port
PORT=11344 python main.py
```

**Flutter App Connection Issues:**
- Ensure service is running on port 11343
- Check firewall settings
- Verify base URL in Lotti settings includes protocol: `http://localhost:11343`

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Lotti Flutter App               │
│         (GemmaInferenceRepository)               │
└──────────────────┬──────────────────────────────┘
                   │ HTTP/REST (Port 11343)
                   ▼
┌─────────────────────────────────────────────────┐
│           FastAPI Service Layer                  │
│  • OpenAI-compatible endpoints                   │
│  • Model name aliasing                           │
│  • Request validation                            │
│  • SSE streaming handler                         │
└──────────────────┬──────────────────────────────┘
                   │
┌─────────────────────────────────────────────────┐
│           Model Management Layer                 │
│  • Hugging Face model downloads                  │
│  • Smart device detection (GPU/CPU)              │
│  • Memory-aware fallback logic                   │
│  • Model loading/unloading                       │
└──────────────────┬──────────────────────────────┘
                   │
┌─────────────────────────────────────────────────┐
│           Inference Engine                       │
│  • Transformers (google/gemma-3n-E2B-it)         │
│  • Audio processing (librosa/torchaudio)         │
│  • Synchronous CPU inference                     │
│  • Threaded chat streaming                       │
└─────────────────────────────────────────────────┘
```

## Security Considerations

- **Local Processing**: All data is processed locally, never sent to external servers
- **No API Keys Required**: For local deployment (only HuggingFace for download)
- **Network Isolation**: Can run completely offline after model download
- **Data Privacy**: Audio and text data remain on your device
- **CORS Enabled**: Allows cross-origin requests for local development

## Known Limitations

1. **Streaming**: Audio transcription uses pseudo-streaming (generates full response first)
2. **CPU Threading**: Audio inference runs synchronously, may block concurrent requests
3. **Memory Usage**: Multimodal models require significant memory (10GB+)
4. **Model Size**: Initial download is large (~10.13GB for gemma-3n-E2B-it)
5. **Audio Formats**: Best results with WAV, MP3, M4A at 16kHz sample rate

## Future Enhancements

- [ ] True streaming for audio transcription
- [ ] Threaded inference for better concurrency
- [ ] Support for more audio formats
- [ ] Multi-language transcription with automatic language detection
- [ ] Fine-tuning support for domain-specific models
- [ ] WebSocket support for real-time streaming
- [ ] Batch transcription API for multiple files
- [ ] Speaker diarization for multi-speaker audio
- [ ] Model quantization options for smaller memory footprint

## License

This service is part of the Lotti project and follows the same license terms.

## Contributing

Contributions are welcome! Please ensure:
1. All tests pass (`pytest`)
2. Code follows the existing style
3. Documentation is updated for new features
4. Docker build succeeds

## Support

For issues specific to the Gemma service, check:
1. Service logs for detailed error messages
2. Memory usage and available resources
3. Model download status
4. Network connectivity for first-time setup

For Lotti integration issues, ensure:
1. Service is running on correct port (11343)
2. Model name matches configuration
3. Audio format is supported
4. Context prompt is properly formatted