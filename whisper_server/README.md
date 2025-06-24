# Whisper API Server

A high-performance, production-ready Python FastAPI server that provides local Whisper transcription with an OpenAI-compatible API interface.

## Features

- ✅ **Local Processing**: Runs Whisper models locally on your hardware
- ✅ **OpenAI Compatible**: Uses OpenAI's API format for seamless integration
- ✅ **High Performance**: Optimized for speed with quantization, flash attention, and hardware acceleration
- ✅ **Multi-GPU Support**: CUDA, MPS (Apple Silicon), and CPU compatibility
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
- **Smaller default model** (whisper-tiny) for speed

### **🔧 Hardware Optimizations**
- **CUDA**: Full optimizations (quantization + flash attention + high batch sizes)
- **MPS (Apple Silicon)**: GPU acceleration with optimized parameters
- **CPU**: Optimized batch processing and model caching

## Setup

### **1. Install Dependencies**
```bash
cd whisper_server
pip install -r requirements.txt
```

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

1. **Install PyInstaller:**
   ```bash
   pip install pyinstaller
   ```

2. **Build the executable:**
   ```bash
   pyinstaller whisper_api_server.spec
   ```

3. **Run the executable:**
   ```bash
   ./dist/whisper_api_server
   ```

### **Command Line Tool**

For direct file transcription, use the CLI tool:

```bash
python whisper_server.py path/to/audio.m4a
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
OpenAI-compatible endpoint that proxies to `/v1/audio/transcriptions`.

### **GET `/health`**
Health check endpoint.

### **POST `/debug/audio-info`**
Debug endpoint to get information about audio data without transcribing.

## Supported Models

The server supports the following Whisper models (optimized for performance):

| Model | Size | Speed | Quality | Default |
|-------|------|-------|---------|---------|
| `whisper-1` | ~39MB | Fastest | Good | ✅ |
| `whisper-tiny` | ~39MB | Fastest | Good | |
| `whisper-small` | ~244MB | Fast | Better | |
| `whisper-medium` | ~769MB | Medium | Better | |
| `whisper-large` | ~1550MB | Slow | Best | |

**Note**: `whisper-1` maps to `whisper-tiny` for optimal speed.

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