# FastWhisper Integration for Lotti

This integration provides speech-to-text transcription capabilities for the Lotti application using FastWhisper, a high-performance speech recognition system.

## Overview

FastWhisper is integrated into Lotti to provide efficient and accurate audio transcription. The system consists of two main components:

1. A FastAPI server that handles the transcription requests
2. A Flutter client service that communicates with the server

## Features

- Real-time audio transcription
- Multiple model support (small, base, large-v3)
- Automatic language detection
- Progress tracking during transcription
- Segment-level transcription with timestamps
- Fallback to WhisperKit when FastWhisper is unavailable

## Prerequisites

- Python 3.8 or higher
- Flutter SDK
- CUDA-compatible GPU (recommended for better performance)

## Server Setup

1. Install the required Python packages:
```bash
pip install -r requirements.txt
```

2. Start the FastWhisper server:
```bash
python fastwhisper_server.py
```

The server will start on `http://localhost:8000` by default.

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
final fastWhisper = FastWhisperService(baseUrl: fastWhisperUrl);
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
- GPU acceleration is recommended for better performance

## Testing

Run the test script to verify the setup:
```bash
python test_transcribe.py
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

This integration is part of the Lotti project and follows its licensing terms. 