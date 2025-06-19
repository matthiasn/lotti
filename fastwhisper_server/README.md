# FastWhisper Integration for Lotti

This integration provides speech-to-text transcription capabilities for the Lotti application using FastWhisper, a high-performance speech recognition system.

## Overview

FastWhisper is integrated into Lotti to provide efficient and accurate audio transcription. The system consists of two main components:

1. A FastAPI server that handles the transcription requests
2. A Flutter client service that communicates with the server

## Features

- Batch audio transcription (not real-time streaming)
- Multiple model support (small, base, large-v3)
- Automatic language detection
- Progress tracking during transcription
- Segment-level transcription with timestamps

## Installation

### For Intel Macs
```bash
pip install -r requirements.txt
```

### For Apple Silicon Macs
```bash
pip install -r requirements-apple-silicon.txt
```

## Quick Start

1. Download the executable for your platform from the releases
2. Run the executable:
```bash
./fastwhisper_server_mac --port 8083  # For Mac (default port is 8083)
```
The server will start on `http://localhost:8083` by default, but you can change the port using the `--port` option.

## Building from Source

If you need to build the executable yourself:

1. Install PyInstaller:
```bash
pip install pyinstaller
```

2. Build the executable:
```bash
pyinstaller --onefile --name fastwhisper_server_mac --add-data "requirements.txt:." --hidden-import faster_whisper fastwhisper_server.py
```

The executable will be created in the `dist` directory.

Note: The executable is platform-specific. You need to build it on the target platform (Mac, Windows, or Linux).

## Available Models

The integration supports three model sizes:

- `small`: Fastest model, suitable for quick transcriptions
- `base`: Balanced model for general use
- `large-v3`: Most accurate model, requires more resources

## API Endpoints

### POST /transcribe

Transcribes audio data and returns the transcription result.

**Request Body:**
```json
{
    "audio": "base64_encoded_audio_data",
    "model": "base",
    "language": "auto"
}
```

**Response:**
```json
{
    "text": "Transcribed text",
    "language": "detected_language",
    "segments": [
        {
            "id": 0,
            "start": 0.0,
            "end": 2.5,
            "text": "Segment text"
        }
    ]
}
```

## Client Integration

The Flutter client integrates with the FastWhisper server through the `FastWhisperService` class. To use it:

1. Configure the server URL in your settings:
```dart
await settingsDb.setItem('fastwhisper_url', 'http://localhost:8000');
```

2. Use the service for transcription:
```dart
final fastWhisper = FastWhisperService(baseUrl: fastwhisperUrl);
final result = await fastWhisper.transcribe(audioFilePath);
```

## Error Handling

The integration includes comprehensive error handling:

- Server connection issues
- Invalid audio file formats
- Transcription failures
- Model loading errors

## Performance Considerations

- The server uses temporary files for audio processing
- Audio files are processed in base64 format
- Consider using the appropriate model size based on your needs

