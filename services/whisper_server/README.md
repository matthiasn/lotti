# Whisper API Server

A high-performance, production-ready Python FastAPI server that provides local Whisper transcription with an OpenAI-compatible API interface.

## Features

- ✅ **Local Processing**: Runs Whisper models locally on your hardware
- ✅ **OpenAI Compatible**: Uses OpenAI's API format for seamless integration
- ✅ **High Performance**: Optimized for speed with quantization, flash attention, and hardware acceleration
- ✅ **Multi-platform Device Selection**: Automatically picks a single best device among CUDA, MPS (Apple Silicon), or CPU
- ✅ **Audio Preprocessing**: Automatic resampling, normalization, and silence trimming
- ✅ **Secure**: Input validation, file size limits, format detection
- ✅ **Configurable**: Environment-based configuration
- ✅ **Production-ready**: Error handling, logging, health checks
- ✅ **Multi-format Support**: MP3, MP4, M4A, WAV, FLAC, OGG, WebM

## Performance Optimizations

### **🚀 Speed Improvements**
- **4-6x faster** than basic Whisper implementations
- **8-bit quantization** for GPU acceleration (CUDA)
- **Flash Attention 2** for faster attention computation (CUDA)
- **Torch compile** for JIT optimization
- **Optimized batch sizes** based on hardware
- **Audio preprocessing** for optimal model performance

### **🔧 Hardware Optimizations**
- **CUDA**: Full optimizations (quantization + flash attention + high batch sizes)
- **MPS (Apple Silicon)**: GPU acceleration with optimized parameters
- **CPU**: Optimized batch processing and model caching

## Setup

### **1. Install Dependencies**

Choose the requirements file for your platform:

```bash
cd services/whisper_server

# For CUDA GPUs (NVIDIA):
pip install -r requirements.txt

# For Apple Silicon (M1/M2/M3/M4):
pip install -r requirements_apple_silicon.txt

# For macOS Intel:
pip install -r requirements_macos_intel.txt

# For Linux (CPU or generic):
pip install -r requirements_linux.txt
```

**Platform-specific notes**:
- **requirements.txt**: Full CUDA support with flash attention and 8-bit quantization
- **requirements_apple_silicon.txt**: Optimized for MPS acceleration on Apple Silicon
- **requirements_linux.txt**: Simplified dependencies for Linux without CUDA

**Note**: Some optimizations require specific hardware/software:
- **Flash Attention**: Requires CUDA and may need compilation
- **8-bit Quantization**: Works best with CUDA GPUs
- **MPS**: Automatic on Apple Silicon Macs

### **2. Configure Environment (Optional)**
```bash
export WHISPER_SERVER_PORT="8084"
export MAX_AUDIO_FILE_SIZE_MB="25"
export LOG_LEVEL="INFO"
export ALLOWED_ORIGINS="http://localhost:3000"
```

## Usage

### **Start the Server**
```bash
python whisper_api_server.py
```

The server will:
- Start on `http://127.0.0.1:8084` by default
- Automatically detect and optimize for your hardware
- Download models on first use (models are cached afterward)
- Log performance optimizations being used

### **Building and Running as Executable**

Build a standalone executable using PyInstaller:

```bash
# Using the build script (recommended)
./build_binary.sh

# Or manually:
pip install pyinstaller
pyinstaller whisper_api_server.spec
```

Run the executable:
```bash
./dist/whisper_api_server
```

### **Pre-built Binaries**

Pre-built binaries for Linux and macOS are available in [GitHub Releases](https://github.com/matthiasn/lotti/releases):

| Platform | Architecture | Filename |
|----------|--------------|----------|
| Linux | x64 | `whisper_server-linux-x64.tar.gz` |
| macOS | Apple Silicon (ARM64) | `whisper_server-macos-arm64.tar.gz` |

There is no pre-built macOS Intel (x64) binary; the release workflow only builds Linux x64 and macOS ARM64. Intel macOS users must build from source (see Setup, using `requirements_macos_intel.txt`).

Download and extract:

```bash
# Linux (x64)
tar -xzvf whisper_server-linux-x64.tar.gz
./whisper_api_server

# macOS Apple Silicon (M1/M2/M3/M4)
tar -xzvf whisper_server-macos-arm64.tar.gz
./whisper_api_server
```

### **Command Line Tool**

`whisper_server.py` is a thin client for the **remote** OpenAI hosted Whisper API, not the local server. It does not run any local model: it requires an `OPENAI_API_KEY` and POSTs the file to `OPENAI_BASE_URL` (default `https://api.openai.com/v1`), so it incurs API usage and is unrelated to the local FastAPI server above.

```bash
export OPENAI_API_KEY="sk-..."
python whisper_server.py path/to/audio.m4a [model]
```

## API Endpoints

### **POST `/v1/audio/transcriptions`**
Transcribe audio using local Whisper models.

**Request:**
```json
{
  "audio": "base64_encoded_audio_data",
  "model": "whisper-1",
  "language": "auto"
}
```

**Response:**
```json
{
  "text": "Transcribed text here...",
  "processing_time": 1.2,
  "model": "whisper-1",
  "format": "m4a"
}
```

### **POST `/v1/chat/completions`**
Convenience alias that forwards the same request body to `/v1/audio/transcriptions` and returns the transcription response shape (`text`, `processing_time`, `model`, `format`) — not an OpenAI ChatCompletion object.

### **GET `/health`**
Health check endpoint.

### **POST `/debug/audio-info`**
Debug endpoint to get information about audio data without transcribing.

## Supported Models

The server supports the following Whisper models (optimized for performance):

| Model | Size | Speed | Quality | Default |
|-------|------|-------|---------|---------|
| `whisper-1` | ~1550MB | Slow | Best | ✅ |
| `whisper-tiny` | ~39MB | Fastest | Good | |
| `whisper-small` | ~244MB | Fast | Better | |
| `whisper-medium` | ~769MB | Medium | Better | |
| `whisper-large` | ~1550MB | Slow | Best | |

**Note**: `whisper-1` maps to `openai/whisper-large-v3` (the same model as `whisper-large`) for accuracy comparable to the hosted OpenAI service.

## Hardware Requirements

### **Minimum Requirements**
- **CPU**: Any modern CPU
- **RAM**: 4GB minimum, 8GB+ recommended
- **Storage**: 1-3GB for models (downloaded automatically)

### **Optimized Performance**
- **CUDA GPU**: NVIDIA GPU with CUDA support (best performance)
- **Apple Silicon**: M1/M2/M3 Macs with MPS support (very good performance)
- **Modern CPU**: Intel/AMD with AVX support (good performance)

## Performance Benchmarks

Typical transcription times for 1-minute audio:

| Hardware | Model | Time | Speedup |
|----------|-------|------|---------|
| M1 Mac (MPS) | whisper-tiny | ~2-4s | 4-6x |
| RTX 3080 (CUDA) | whisper-tiny | ~1-2s | 6-8x |
| Intel i7 (CPU) | whisper-tiny | ~8-15s | 2-3x |

*Times include preprocessing and model loading on first run*

**Note**: These figures are measured with `whisper-tiny`. The default model (`whisper-1`) resolves to `openai/whisper-large-v3`, which is substantially larger and slower; pass `whisper-tiny` explicitly to get the speeds above.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WHISPER_SERVER_HOST` | `127.0.0.1` | Server host address |
| `WHISPER_SERVER_PORT` | `8084` | Server port |
| `MAX_AUDIO_FILE_SIZE_MB` | `25` | Maximum audio file size in MB |
| `ALLOWED_ORIGINS` | `http://localhost:3000` | CORS allowed origins (comma-separated) |
| `ALLOWED_HOSTS` | `*` | Trusted hosts (comma-separated) |
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |

## Integration with Flutter App

This server is designed to work seamlessly with the Lotti Flutter app:

1. **Configure Provider**: Add a new Whisper provider in AI settings
2. **Base URL**: `http://localhost:8084`
3. **No API Key Required**: Leave API key field empty
4. **Model Selection**: Choose any supported model name
5. **Automatic Optimization**: Server automatically optimizes for your hardware

The app uses the same OpenAI-compatible API format, making integration seamless.

## Troubleshooting

### **Common Issues**

**Model Download Slow/Fails**
- Check internet connection for first-time model download
- Models are cached locally after first download

**Flash Attention Errors**
- Flash attention only works on CUDA GPUs
- Server automatically falls back to standard attention
- This is normal and expected on MPS/CPU

**Memory Issues**
- Use smaller models (`whisper-tiny` or `whisper-small`)
- Reduce batch size by setting lower values in environment
- Close other applications to free up memory

**Port Already in Use**
- Change port: `export WHISPER_SERVER_PORT="8085"`
- Check if another Whisper server is running

### **Performance Tips**

1. **For fastest transcription**: Use `whisper-tiny` model
2. **For best quality**: Use `whisper-large` model  
3. **For CUDA GPUs**: Ensure CUDA drivers are up to date
4. **For Apple Silicon**: Ensure macOS is updated for best MPS support
5. **First run**: Allow extra time for model download and compilation

## Dependencies

The server requires the following key packages:

```
torch>=2.0.0              # PyTorch for model inference
transformers>=4.30.0       # Hugging Face transformers
accelerate>=0.20.0         # Hardware acceleration
bitsandbytes>=0.43.0       # 8-bit quantization
flash-attn>=2.0.0          # Flash attention (CUDA only)
librosa>=0.10.0            # Audio processing
soundfile>=0.12.0          # Audio file I/O
audioread>=3.0.0           # Audio format support
fastapi>=0.68.0            # Web framework
uvicorn>=0.15.0            # ASGI server
```

**Note**: Some packages (flash-attn, bitsandbytes) may require compilation and are optional for basic functionality.

## License

This project follows the same license as the main Lotti application. 