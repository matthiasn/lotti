# Gemma Audio Transcription Service

A high-performance, production-ready audio transcription service powered by Google's Gemma 3N models. This service provides OpenAI-compatible API endpoints for audio transcription with support for context-aware processing and multiple model variants.

## Features

- **Gemma 3N Multimodal Model**: Powered by Google's Gemma 3N models with native audio support
- **OpenAI-Compatible API**: Drop-in replacement for OpenAI's transcription endpoints
- **Multiple Model Variants**: Support for both E2B (2B) and E4B (4B) Gemma variants
- **Context-Aware Transcription**: Improve accuracy with contextual prompts
- **Multi-Format Support**: WAV, MP3, M4A, FLAC, OGG, and WebM audio formats
- **Automatic Chunking**: Handles audio longer than 30 seconds with intelligent chunking
- **Automatic Model Management**: Auto-download models on first use
- **Production Ready**: Comprehensive error handling, logging, and resource management
- **Streaming Support**: Real-time streaming responses for chat completions
- **Docker Support**: Containerized deployment option
- **MPS Support**: Optimized for Apple Silicon acceleration

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

### Model Management

#### Download Models

**Important**: Models are downloaded automatically on first use, but you can pre-download them using the included script:

```bash
# Download E2B model (default, smaller)
python download_model.py

# Download E4B model (larger, better quality)
python download_model.py E4B

# Download both variants
python download_model.py both
```

If you encounter authentication errors, you'll need a HuggingFace token:
```bash
# Get token from https://huggingface.co/settings/tokens
python download_model.py --token YOUR_HF_TOKEN
```

### Running the Service

#### Using the Start Script (Recommended)

Use the convenient startup script:
```bash
# Default E2B model
./start_server.sh

# Use E4B model
GEMMA_MODEL_VARIANT=E4B ./start_server.sh
```

#### Manual Startup

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

#### Method 1: All-in-One Script (Recommended)

Use the automated script that handles everything:
```bash
# Make the script executable (first time only)
chmod +x run_transcription.sh

# Transcribe any audio file
./run_transcription.sh /path/to/audio.m4a

# Example:
./run_transcription.sh ~/Desktop/recording.m4a
```

The `run_transcription.sh` script automatically:
- Cleans up any existing servers
- Starts the Gemma 3N service
- Waits for server initialization
- Processes your audio file
- Shows the transcription result
- Stops the server when complete

#### Method 2: Python Script

For more control, use the Python script directly:
```bash
# Transcribe any audio file (auto-converts M4A/MP3/etc to WAV)
python transcribe.py /path/to/audio.m4a

# The script will:
# - Install dependencies if needed
# - Convert audio format automatically
# - Handle audio chunking for files > 30 seconds
# - Start server, transcribe, show results
```

#### Method 3: Standalone Utility

For running with an already-started server:
```bash
# Start the server first
python main.py

# In another terminal, run transcription
python transcribe_utils_standalone.py /path/to/audio.m4a
```

### Testing

Run the comprehensive test suite:
```bash
# Install dependencies first
pip install -r requirements.txt

# Run all tests with E2B model
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
| `HOST` | `127.0.0.1` | Service host |
| `LOG_LEVEL` | `INFO` | Logging level |
| `MAX_AUDIO_SIZE_MB` | `50` | Maximum audio file size |
| `MAX_CONCURRENT_REQUESTS` | `2` | Maximum concurrent requests |
| `REQUEST_TIMEOUT` | `600` | Request timeout in seconds |
| `AUDIO_CHUNK_SIZE_SECONDS` | `30` | Audio chunk size (30s max for Gemma 3N) |
| `AUDIO_OVERLAP_SECONDS` | `2` | Overlap between chunks in seconds |
| `MAX_TOKENS` | `2000` | Maximum tokens for generation |
| `MAX_TOKENS_TRANSCRIPTION` | `2000` | Maximum tokens for transcription |
| `CPU_MAX_NEW_TOKENS` | `2000` | Maximum new tokens for CPU mode |
| `GEMMA_DEVICE` | `auto` | Device selection (`auto`, `cuda`, `cpu`, `mps`) |
| `LOW_MEMORY_MODE` | `true` | Enable memory optimizations |
| `MAX_MEMORY_GB` | `8` | Maximum memory usage |

## Model Variants and Requirements

### E2B (2 Billion Parameters) - Default
- **Size**: ~5.4 GB
- **Speed**: Fast inference for audio transcription
- **Memory**: Lower requirements (~6GB RAM)
- **Use Case**: Real-time transcription, resource-constrained environments
- **Accuracy**: Good for most use cases

### E4B (4 Billion Parameters)
- **Size**: ~10.8 GB
- **Speed**: Slower inference than E2B
- **Memory**: Higher requirements (~12GB RAM)
- **Use Case**: Maximum accuracy, batch processing
- **Accuracy**: Higher quality transcription

## Audio Limitations and Specifications

### Gemma 3N Audio Constraints
- **Maximum chunk size**: 30 seconds (model limitation)
- **Automatic chunking**: Files longer than 30s are split automatically
- **Sample rate**: 16kHz (auto-converted)
- **Format**: Mono audio (stereo converted automatically)
- **Maximum file size**: 50MB (configurable)
- **Supported formats**: WAV, MP3, M4A, FLAC, OGG, WebM

### Processing Times
- Processing time varies based on hardware, model variant, and audio length
- E2B model is generally faster than E4B
- Performance is optimized for Apple Silicon (MPS) devices

### Device Compatibility
- **Apple Silicon (MPS)**: Recommended for best performance
- **CUDA GPU**: Supported with sufficient VRAM
- **CPU**: Fallback option, slower but works

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
  gemma-local:
    build: .
    container_name: gemma-local-service
    ports:
      - "11343:11343"
    volumes:
      # Mount model cache to persist downloads
      - gemma-models:/root/.cache/gemma-local/models
      # Mount logs
      - gemma-logs:/root/.logs/gemma-local
    environment:
      - GEMMA_MODEL_ID=${GEMMA_MODEL_ID:-google/gemma-3n-E2B-it}
      - LOG_LEVEL=${LOG_LEVEL:-INFO}
      - MAX_AUDIO_SIZE_MB=${MAX_AUDIO_SIZE_MB:-100}
      - MAX_CONCURRENT_REQUESTS=${MAX_CONCURRENT_REQUESTS:-4}
      - REQUEST_TIMEOUT=${REQUEST_TIMEOUT:-300}
    restart: unless-stopped

volumes:
  gemma-models:
    driver: local
  gemma-logs:
    driver: local
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

#### Model Not Found (HTTP 404 Error)

If you get a 404 error when trying to use a model variant, it means the model isn't downloaded yet:

```bash
# Error message example:
# INFO: 127.0.0.1:64309 - "POST /v1/chat/completions HTTP/1.1" 404 Not Found

# Solution: Download the model first
python download_model.py E4B  # or whichever variant you're trying to use

# Then restart the server with that variant
GEMMA_MODEL_VARIANT=E4B ./start_server.sh
```

#### Model Download Fails
```bash
# Clear cache and retry
rm -rf ~/.cache/gemma-local/models
python download_model.py

# Or use the manual method
python main.py
```

#### HuggingFace Authentication Required
Gemma models require authentication. Set up your token:
```bash
# Get token from https://huggingface.co/settings/tokens
export HF_TOKEN=your_token_here

# Or set in environment permanently
echo 'export HF_TOKEN=your_token_here' >> ~/.bashrc
source ~/.bashrc
```

#### Permission Denied on Script
```bash
# Make script executable
chmod +x run_transcription.sh

# Or run with bash directly
bash run_transcription.sh /path/to/audio.m4a
```

#### Virtual Environment Not Found
```bash
# Create virtual environment first
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Then run the script
./run_transcription.sh /path/to/audio.m4a
```

#### Audio File Not Found
```bash
# Use absolute path
./run_transcription.sh /full/path/to/audio.m4a

# Or check current directory
ls -la ~/Desktop/audio.m4a
```

#### Server Startup Fails
```bash
# Check if port is in use
lsof -i :11343

# Kill existing processes
lsof -i :11343 | grep LISTEN | awk '{print $2}' | xargs kill -9

# Check logs for errors
tail -f /tmp/gemma_server.log
```

#### Transcription Takes Too Long
```bash
# Use E2B model for faster processing
GEMMA_MODEL_VARIANT=E2B ./run_transcription.sh /path/to/audio.m4a

# Or reduce audio length
ffmpeg -i input.m4a -t 30 -c copy short_audio.m4a
```

#### Out of Memory
```bash
# Enable low memory mode
LOW_MEMORY_MODE=true MAX_MEMORY_GB=4 python main.py

# Use CPU instead of GPU
GEMMA_DEVICE=cpu python main.py
```

#### Audio Format Not Supported
```bash
# Convert to supported format first
ffmpeg -i input.mp4 -vn -acodec pcm_s16le -ar 16000 -ac 1 output.wav
./run_transcription.sh output.wav
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

## Architecture

This service features a **modular architecture** designed for testability, maintainability, and engineering best practices:

### Legacy Service (main.py)
The original monolithic implementation that provides all functionality in a single file.

### New Modular Service (src/)
A restructured, modular implementation with the following benefits:
- **Separation of Concerns**: Domain, service, API, and adapter layers
- **Dependency Injection**: Interface-based design for easy testing and mocking
- **Comprehensive Testing**: Unit tests, integration tests, and CI/CD pipeline
- **Type Safety**: Full type hints and interface definitions

```
src/
├── core/                    # Domain models and interfaces
│   ├── models.py           # Data models and DTOs
│   ├── interfaces.py       # Service interfaces
│   └── exceptions.py       # Custom exceptions
├── services/               # Business logic implementations
│   ├── config_manager.py   # Configuration management
│   ├── model_validator.py  # Model validation logic
│   ├── transcription_service.py # Audio transcription
│   └── chat_service.py     # Chat completions
├── adapters/               # Legacy code adapters
├── api/                    # HTTP API layer
├── legacy/                 # Bridges to existing code
└── container.py            # Dependency injection container
```

### Running the Services

#### Legacy Service
```bash
python main.py
```

#### New Modular Service
```bash
python -m src.main_new
# or with auto-reload
uvicorn src.main_new:app --reload
```

Both services provide identical API compatibility.

## Development

### Setting Up Development Environment

```bash
# Create virtual environment
make setup-env
source venv/bin/activate

# Install all dependencies
make install-dev
```

### Running Tests

#### Quick Test Suite
```bash
# Run the automated test runner
python run_tests.py

# Or using the Makefile
make test
```

#### Detailed Testing
```bash
# Unit tests only
make test-unit
pytest tests/unit -v

# Integration tests only
make test-integration
pytest tests/integration -v

# Run with coverage
pytest --cov=src --cov-report=html --cov-report=term-missing

# Test specific service
pytest tests/unit/test_transcription_service.py -v
```

### Code Quality

```bash
# Run all quality checks
make check-all

# Individual checks
make lint          # Linting with flake8
make format        # Code formatting with black/isort
make type-check    # Type checking with mypy
make security-scan # Security scanning
```

### Available Make Commands

```bash
make help          # Show all available commands
make install-dev   # Install dev dependencies
make test          # Run all tests
make test-unit     # Run unit tests only
make test-integration # Run integration tests only
make lint          # Run linting
make format        # Format code
make type-check    # Type checking
make security-scan # Security scans
make clean         # Clean build artifacts
make run           # Run legacy service
make run-new       # Run modular service
make docker-build  # Build Docker image
make benchmark     # Run performance benchmark
```

### Testing Strategy

- **Unit Tests**: Mock all dependencies, test business logic in isolation
- **Integration Tests**: Test API endpoints and service interactions
- **Mocking**: Comprehensive mocking of external dependencies
- **Coverage**: Maintain high test coverage (>80%)
- **CI/CD**: Automated testing in GitHub Actions

### GitHub Actions CI/CD

The project includes a comprehensive CI/CD pipeline:

#### Test Matrix
- **Python versions**: 3.9, 3.10, 3.11
- **Test types**: Unit tests, integration tests
- **Coverage reporting**: Codecov integration
- **Code quality**: Linting, type checking, formatting

#### Security & Quality
- **Security scanning**: Safety (vulnerabilities) and Bandit (security issues)
- **Performance testing**: Basic load testing with Locust
- **Docker integration**: Build and test containerized deployments

#### Workflow Triggers
- **Push to main/develop**: Full test suite
- **Pull requests**: All checks + performance tests
- **Changes to service files**: Automatic testing

### Development Workflow

1. **Make changes** to service code
2. **Write tests** for new functionality
3. **Run quality checks**: `make check-all`
4. **Test locally**: `make test`
5. **Submit PR**: GitHub Actions runs full test suite

### Contributing Guidelines

When contributing to the modular architecture:

1. **Follow existing patterns**: Use dependency injection and interfaces
2. **Write comprehensive tests**: Both unit and integration tests
3. **Maintain type safety**: Include type hints for all functions
4. **Update documentation**: Keep README and docstrings current
5. **Run full test suite**: Ensure all tests pass before submitting

### Code Quality Standards

The codebase follows these standards:
- **Type hints** for all functions and methods
- **Comprehensive docstrings** following Google/NumPy style
- **Error handling and logging** at appropriate levels
- **Async/await best practices** for concurrent operations
- **Security input validation** for all user inputs
- **SOLID principles** in service design
- **Interface segregation** for better testability
- **Dependency inversion** through dependency injection

### Performance Considerations

- **Service isolation**: Individual services can be optimized independently
- **Caching strategies**: Interface-based caching implementations
- **Resource management**: Proper cleanup and memory management
- **Monitoring**: Clear service boundaries for better observability

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