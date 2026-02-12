# Qwen Image Service

Local text-to-image generation service using the [Qwen/Qwen-Image](https://huggingface.co/Qwen/Qwen-Image) model from Alibaba/Qwen. Generates high-quality images from text prompts, running entirely on your machine with no cloud dependency.

## Features

- **Text-to-image generation** with Qwen-Image diffusion model
- **Multiple aspect ratios**: 1:1, 16:9, 9:16, 4:3, 3:4, 3:2, 2:3
- **Hardware acceleration**: CUDA (NVIDIA), MPS (Apple Silicon), CPU fallback
- **OpenAI-compatible API** for easy integration
- **Model management**: Download, load, and unload via API
- **No API key required** (Apache 2.0 license)
- **Desktop only** (requires GPU for reasonable performance)

## Requirements

- Python 3.10+
- GPU recommended:
  - **NVIDIA**: RTX 3060+ (8GB+ VRAM) with CUDA
  - **Apple Silicon**: 16GB+ unified memory with MPS
  - **CPU**: Works but very slow (10+ minutes per image)
- ~10GB disk space for model weights

## Quick Start

```bash
# Set up virtual environment
make setup-env
source venv/bin/activate

# Install dependencies
make install

# Start the service
make run
```

The service starts on `http://127.0.0.1:11345`.

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check with model status |
| `/v1/images/generate` | POST | Generate image from text prompt |
| `/v1/models` | GET | List available models |
| `/v1/models/pull` | POST | Download model (SSE progress) |
| `/v1/models/load` | POST | Load model into memory |

### Generate Image

```bash
curl -X POST http://localhost:11345/v1/images/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A serene mountain landscape at sunset, oil painting style",
    "width": 1664,
    "height": 928,
    "num_inference_steps": 50,
    "cfg_scale": 4.0
  }'
```

**Response:**
```json
{
  "data": [{"b64_json": "<base64 PNG>", "mime_type": "image/png"}],
  "model": "Qwen/Qwen-Image",
  "seed": 12345,
  "generation_time": 25.3
}
```

### Download Model

```bash
curl -X POST http://localhost:11345/v1/models/pull \
  -H "Content-Type: application/json" \
  -d '{"model_name": "Qwen/Qwen-Image", "stream": false}'
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `127.0.0.1` | Server bind address |
| `PORT` | `11345` | Server port |
| `LOG_LEVEL` | `INFO` | Logging level |
| `QWEN_IMAGE_MODEL_ID` | `Qwen/Qwen-Image` | HuggingFace model ID |
| `QWEN_IMAGE_DEVICE` | `auto` | Device: auto, cuda, mps, cpu |
| `QWEN_IMAGE_WIDTH` | `1664` | Default image width |
| `QWEN_IMAGE_HEIGHT` | `928` | Default image height |
| `QWEN_IMAGE_STEPS` | `50` | Default inference steps |
| `QWEN_IMAGE_CFG_SCALE` | `4.0` | Default CFG scale |
| `QWEN_IMAGE_TIMEOUT` | `300` | Generation timeout (seconds) |
| `HF_TOKEN` | - | Optional HuggingFace token |

## Architecture

```
qwen-image/
├── config.py              # ServiceConfig - env-var-driven settings
├── model_manager.py       # QwenImageModelManager - download, load, unload
├── image_generator.py     # ImageGenerator - generation logic (testable)
├── main.py                # FastAPI app - endpoints, middleware, logging
├── tests/
│   ├── conftest.py        # Shared fixtures
│   ├── test_config.py     # Config tests
│   ├── test_model_manager.py  # Model manager tests
│   ├── test_image_generator.py # Image generator tests
│   └── test_endpoints.py  # API endpoint tests
├── requirements.txt       # Production dependencies
├── requirements-dev.txt   # Dev/test dependencies
├── Makefile               # Build/test/run commands
├── .env.example           # Configuration template
└── start_server.sh        # Shell launcher
```

The service separates concerns into three layers:
- **`config.py`**: All configuration from environment variables
- **`model_manager.py`**: Model lifecycle (download, load, unload, memory management)
- **`image_generator.py`**: Image generation logic, independently testable

## Development

```bash
# Run tests
make test

# Run tests with coverage
make test-cov

# Lint
make lint

# Format code
make format
```

## Performance Notes

| Device | ~Generation Time (50 steps, 1664x928) |
|--------|---------------------------------------|
| RTX 4090 | ~10-15s |
| RTX 3060 | ~30-45s |
| Apple M2 Pro | ~40-60s |
| CPU | 10+ minutes |

Generation time scales linearly with inference steps. Reduce `QWEN_IMAGE_STEPS` for faster (lower quality) results.
