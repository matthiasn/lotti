# Whisper API Server

A secure, production-ready Python FastAPI server that proxies OpenAI's Whisper API for audio transcription.

## Features

- ✅ **Secure**: Input validation, file size limits, format detection
- ✅ **Configurable**: Environment-based configuration
- ✅ **Production-ready**: Error handling, logging, health checks
- ✅ **OpenAI Compatible**: Uses OpenAI's Whisper API
- ✅ **Multi-format Support**: MP3, MP4, M4A, WAV, FLAC, OGG, WebM

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Set your OpenAI API key:
```bash
export OPENAI_API_KEY="your-api-key-here"
```

3. (Optional) Configure additional settings:
```bash
export WHISPER_SERVER_PORT="8084"
export MAX_AUDIO_FILE_SIZE_MB="25"
export LOG_LEVEL="INFO"
```

## Usage

### Start the Server
```bash
python whisper_api_server.py
```

The server will start on `http://127.0.0.1:8084` by default.

### Building and Running as Executable

You can build a standalone executable using PyInstaller:

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
   # Set required environment variables
   export OPENAI_API_KEY="your-api-key-here"
   
   # Run the executable
   ./dist/whisper_api_server
   ```

   **Note:** The executable requires the same environment variables as the Python script. Make sure to set `OPENAI_API_KEY` before running.

### Command Line Tool

For direct file transcription without starting a server, use the CLI tool:

```bash
python whisper_server.py path/to/audio.m4a
```

This will transcribe the specified audio file and output the result to the console.

### API Endpoints

#### POST `/v1/audio/transcriptions`
Transcribe audio using OpenAI's Whisper API.

**Request:**
```json
{
  "audio": "base64_encoded_audio_data",
  "model": "whisper-1"
}
```

**Response:**
```json
{
  "text": "Transcribed text here...",
  "processing_time": 3.45,
  "model": "whisper-1",
  "format": "m4a"
}
```

#### POST `/v1/chat/completions`
OpenAI-compatible endpoint that proxies to `/v1/audio/transcriptions`.

#### GET `/health`
Health check endpoint.

### Testing

You can test the API endpoints using curl or any HTTP client:

```bash
# Health check
curl http://localhost:8084/health

# Test transcription (replace with your actual base64 audio data)
curl -X POST http://localhost:8084/v1/audio/transcriptions \
  -H "Content-Type: application/json" \
  -d '{
    "audio": "base64_encoded_audio_data_here",
    "model": "whisper-1"
  }'
```

For manual testing with audio files, you can use the CLI tool:
```bash
python whisper_server.py path/to/your/audio.m4a
```

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `OPENAI_API_KEY` | Required | Your OpenAI API key |
| `OPENAI_BASE_URL` | `https://api.openai.com/v1` | OpenAI API base URL |
| `WHISPER_SERVER_HOST` | `127.0.0.1` | Server host |
| `WHISPER_SERVER_PORT` | `8084` | Server port |
| `MAX_AUDIO_FILE_SIZE_MB` | `25` | Maximum audio file size in MB |
| `RATE_LIMIT_REQUESTS` | `10` | Rate limit requests per window |
| `RATE_LIMIT_WINDOW` | `1 minute` | Rate limit time window |
| `ALLOWED_ORIGINS` | `http://localhost:3000` | CORS allowed origins |
| `LOG_LEVEL` | `INFO` | Logging level |

## Security Features

- **Input Validation**: Validates base64 encoding, file size, and format
- **File Size Limits**: Configurable maximum file size (default: 25MB)
- **Format Detection**: Automatically detects audio format from file headers
- **Error Handling**: Comprehensive error handling and logging
- **CORS Protection**: Configurable CORS settings
- **Request Logging**: Logs client IP and request details

## Supported Audio Formats

- MP3 (`.mp3`)
- MP4/M4A (`.mp4`, `.m4a`)
- WAV (`.wav`)
- FLAC (`.flac`)
- OGG (`.ogg`)
- WebM (`.webm`)

## Error Codes

| Code | Description |
|------|-------------|
| 400 | Bad Request (invalid input, file too large, unsupported format) |
| 500 | Internal Server Error |
| 504 | Gateway Timeout (OpenAI API timeout) |

## Development

### Running in Development
```bash
export LOG_LEVEL="DEBUG"
python whisper_api_server.py
```

### Testing Different Audio Formats
```bash
# Test with MP3
python whisper_server.py test.mp3

# Test with WAV
python whisper_server.py test.wav

# Test with M4A
python whisper_server.py test.m4a
``` 