# Gemma Audio Transcription Service

A high-performance, production-ready audio transcription service powered by Google's Gemma 3N models. This service provides OpenAI-compatible API endpoints for audio transcription with support for context-aware processing and multiple model variants.

## Features

- **OpenAI-Compatible API**: Drop-in replacement for OpenAI's transcription endpoints
- **Multiple Model Variants**: Support for both E2B and E4B Gemma variants
- **Context-Aware Transcription**: Improve accuracy with contextual prompts
- **Multi-Format Support**: WAV, MP3, M4A, FLAC, OGG, and WebM audio formats
- **Automatic Model Management**: Auto-download models on first use
- **Production Ready**: Comprehensive error handling, logging, and resource management
- **Streaming Support**: Real-time streaming responses for chat completions
- **Docker Support**: Containerized deployment option

## Quick Start

### Installation

1. Clone the repository and navigate to the service directory:
```bash
cd services/gemma-local
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

### Running the Service

#### Basic Usage

Start the service with default settings (E2B model variant):
```bash
python main.py
```

#### Specify Model Variant

Use E4B variant (larger, more accurate):
```bash
GEMMA_MODEL_VARIANT=E4B python main.py
```

#### Custom Port

```bash
PORT=8080 python main.py
```

### Quick Start - Transcribe Audio

For immediate transcription use the simple script:
```bash
# Transcribe any audio file (auto-converts M4A/MP3/etc to WAV)
python transcribe.py /path/to/audio.m4a

# The script will:
# - Install dependencies if needed
# - Convert audio format automatically  
# - Trim to 4 minutes if longer (service limit: 5 minutes)
# - Start server, transcribe, show results
```

### Testing

Run the comprehensive test suite:
```bash
# Install dependencies first
pip install -r requirements.txt

# Run all tests with E2B model (takes 10+ minutes)
python test_transcription.py --run-all

# Test with E4B model  
python test_transcription.py --model e4b --run-all

# Test with specific audio file
python test_transcription.py --audio /path/to/audio.wav

# Run specific test
python test_transcription.py --test transcribe --audio sample.m4a
```

## API Documentation

### Base URL
```
http://localhost:11343
```

### Endpoints

#### Health Check
```http
GET /health
```

Returns service health status and model availability.

**Response:**
```json
{
  "status": "healthy",
  "model_available": true,
  "model_loaded": false,
  "device": "cpu"
}
```

#### List Models
```http
GET /v1/models
```

List available models and their capabilities.

**Response:**
```json
{
  "object": "list",
  "data": [
    {
      "id": "google/gemma-3n-E2B-it",
      "object": "model",
      "created": 1699564800,
      "capabilities": {
        "transcription": true,
        "chat": true,
        "multimodal": true,
        "streaming": true
      },
      "size_gb": 5.4
    }
  ]
}
```

#### Audio Transcription
```http
POST /v1/chat/completions
```

Transcribe audio with optional context.

**Request:**
```json
{
  "model": "gemma-3n-E2B-it",
  "messages": [
    {
      "role": "user",
      "content": "Context: This is a technical discussion.\n\nTranscribe this audio"
    }
  ],
  "audio": "<base64_encoded_audio>",
  "temperature": 0.1,
  "language": "en"
}
```

**Response:**
```json
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1699564800,
  "model": "gemma-3n-E2B-it",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Transcribed text..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 50,
    "completion_tokens": 100,
    "total_tokens": 150
  }
}
```

#### Download Model
```http
POST /v1/models/pull
```

Download model files (automatic on first use).

**Request:**
```json
{
  "model_name": "gemma-3n-E2B-it",
  "stream": true
}
```

#### Load Model
```http
POST /v1/models/load
```

Pre-load model into memory for faster first inference.

## Configuration

Environment variables for service configuration:

| Variable | Default | Description |
|----------|---------|-------------|
| `GEMMA_MODEL_VARIANT` | `E2B` | Model variant (`E2B` or `E4B`) |
| `GEMMA_MODEL_ID` | Auto | Override full model ID |
| `PORT` | `11343` | Service port |
| `HOST` | `0.0.0.0` | Service host |
| `LOG_LEVEL` | `INFO` | Logging level |
| `MAX_AUDIO_SIZE_MB` | `50` | Maximum audio file size |
| `MAX_CONCURRENT_REQUESTS` | `2` | Maximum concurrent requests |
| `REQUEST_TIMEOUT` | `600` | Request timeout in seconds |
| `GEMMA_DEVICE` | `auto` | Device selection (`auto`, `cuda`, `cpu`, `mps`) |
| `LOW_MEMORY_MODE` | `true` | Enable memory optimizations |
| `MAX_MEMORY_GB` | `8` | Maximum memory usage |

## Model Variants

### E2B (2 Billion Parameters)
- **Size**: ~5.4 GB
- **Speed**: Faster inference
- **Memory**: Lower requirements (~6GB RAM)
- **Use Case**: Real-time transcription, resource-constrained environments

### E4B (4 Billion Parameters)
- **Size**: ~10.8 GB
- **Speed**: Slower inference
- **Memory**: Higher requirements (~12GB RAM)
- **Use Case**: Maximum accuracy, batch processing

## Client Examples

### Python Client

```python
import base64
import requests

def transcribe_audio(audio_path, context=None, model_variant="E2B"):
    # Read and encode audio
    with open(audio_path, 'rb') as f:
        audio_base64 = base64.b64encode(f.read()).decode('utf-8')
    
    # Prepare request
    messages = []
    if context:
        messages.append({
            "role": "user",
            "content": f"Context: {context}\n\nTranscribe this audio"
        })
    else:
        messages.append({
            "role": "user",
            "content": "Transcribe this audio"
        })
    
    # Send request
    response = requests.post(
        "http://localhost:11343/v1/chat/completions",
        json={
            "model": f"gemma-3n-{model_variant}-it",
            "messages": messages,
            "audio": audio_base64,
            "temperature": 0.1
        }
    )
    
    # Extract transcription
    result = response.json()
    return result['choices'][0]['message']['content']

# Example usage
transcription = transcribe_audio(
    "meeting.m4a",
    context="Technical discussion about machine learning",
    model_variant="E2B"
)
print(transcription)
```

### cURL Example

```bash
# Encode audio file to base64
AUDIO_BASE64=$(base64 -i audio.wav)

# Send transcription request
curl -X POST http://localhost:11343/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma-3n-E2B-it",
    "messages": [
      {
        "role": "user",
        "content": "Transcribe this audio"
      }
    ],
    "audio": "'$AUDIO_BASE64'",
    "temperature": 0.1
  }'
```

## Docker Deployment

### Build Image

```bash
docker build -t gemma-transcription .
```

### Run Container

```bash
# With E2B model
docker run -p 11343:11343 \
  -e GEMMA_MODEL_VARIANT=E2B \
  -v ~/.cache/gemma-local:/root/.cache/gemma-local \
  gemma-transcription

# With E4B model and GPU support
docker run --gpus all -p 11343:11343 \
  -e GEMMA_MODEL_VARIANT=E4B \
  -e GEMMA_DEVICE=cuda \
  -v ~/.cache/gemma-local:/root/.cache/gemma-local \
  gemma-transcription
```

### Docker Compose

```yaml
version: '3.8'

services:
  gemma-transcription:
    build: .
    ports:
      - "11343:11343"
    environment:
      - GEMMA_MODEL_VARIANT=E2B
      - LOG_LEVEL=INFO
    volumes:
      - ~/.cache/gemma-local:/root/.cache/gemma-local
    deploy:
      resources:
        limits:
          memory: 8G
```

## Performance Optimization

### CPU Optimization
- Automatic inference mode selection
- Optimized generation configs
- Memory-mapped model loading
- Chunked audio processing

### GPU Optimization
- CUDA support with automatic device selection
- Mixed precision (fp16) inference
- Batch processing capabilities

### Memory Management
- Automatic garbage collection
- Model unloading on idle
- Streaming response support
- Configurable memory limits

## Security Considerations

### Input Validation
- File size limits (default 50MB)
- Audio format validation
- Base64 encoding validation
- Request rate limiting

### Best Practices
- Run behind reverse proxy in production
- Enable HTTPS for API endpoints
- Implement authentication if needed
- Monitor resource usage

## Troubleshooting

### Common Issues

#### Model Download Fails
```bash
# Clear cache and retry
rm -rf ~/.cache/gemma-local/models
python main.py
```

#### Out of Memory
```bash
# Enable low memory mode
LOW_MEMORY_MODE=true MAX_MEMORY_GB=4 python main.py
```

#### Slow Inference
```bash
# Use E2B model for faster processing
GEMMA_MODEL_VARIANT=E2B python main.py
```

### Logging

Enable debug logging:
```bash
LOG_LEVEL=DEBUG python main.py
```

View logs:
```bash
tail -f ~/.logs/gemma-local/service.log
```

## Development

### Running Tests

```bash
# Install dev dependencies
pip install -r requirements.txt

# Run tests with coverage
pytest --cov=. --cov-report=html

# Run linting
ruff check .
black --check .

# Type checking
mypy .
```

### Code Quality

The codebase follows these standards:
- Type hints for all functions
- Comprehensive docstrings
- Error handling and logging
- Async/await best practices
- Security input validation

## License

This service is part of the Lotti project. See the main project LICENSE for details.

## Contributing

Contributions are welcome! Please ensure:
1. All tests pass
2. Code passes linting (ruff, black)
3. Type hints are included
4. Documentation is updated

## Support

For issues and questions:
- Open an issue in the main Lotti repository
- Check existing documentation and tests
- Provide logs and reproduction steps