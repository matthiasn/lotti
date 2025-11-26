# AI Proxy Service

An OpenAI-compatible proxy service that forwards AI requests to Google Gemini and tracks billing information.

## Overview

This service acts as a middleware between the Lotti application and AI providers (currently Google Gemini). It provides:

- **OpenAI-compatible API**: Use standard OpenAI client libraries to interact with Gemini
- **API Key Management**: Securely manages AI provider API keys server-side
- **Usage Tracking**: Logs token usage and costs for billing purposes
- **Model Mapping**: Automatically maps OpenAI model names to Gemini equivalents

## Architecture

```text
┌─────────────────┐
│  Lotti App      │
│  (Flutter)      │
│                 │
│ Config:         │
│ endpoint:       │
│ "localhost:8002"│
└────────┬────────┘
         │ POST /v1/chat/completions
         │ {"model": "gpt-4", "messages": [...]}
         ↓
┌─────────────────────────────────┐
│  AI Proxy Service               │
│  ─────────────────────────      │
│  1. Map model (gpt-4 → gemini)  │
│  2. Forward to Gemini API       │
│  3. Parse billing metadata      │
│  4. Log cost & usage            │
│  5. Return OpenAI-format resp   │
└────┬────────────────────────────┘
     │
     ↓
┌──────────────┐
│ Gemini API   │
│              │
│ Returns:     │
│ - Content    │
│ - Tokens     │
│ - Metadata   │
└──────────────┘
```

## Quick Start

### Prerequisites

- Python 3.13+
- Google Gemini API Key ([Get one here](https://makersuite.google.com/app/apikey))
- Docker & Docker Compose (optional, for containerized deployment)

### 1. Set up environment

```bash
cd services/ai-proxy-service

# Copy environment template
cp .env.example .env

# Edit .env and add your Gemini API key
# GEMINI_API_KEY=your_actual_api_key_here
```

### 2. Install dependencies

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
make install
```

### 3. Run the service

```bash
# Run locally
make run

# Or with auto-reload for development
make run-dev
```

The service will start on `http://localhost:8002`

### 4. Test the API

```bash
# Health check
curl http://localhost:8002/health

# Chat completion
curl -X POST http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-pro",
    "messages": [
      {"role": "user", "content": "Hello! How are you?"}
    ],
    "user_id": "test@example.com"
  }'
```

## API Documentation

### Endpoints

#### `POST /v1/chat/completions`

OpenAI-compatible chat completions endpoint.

**Request:**

```json
{
  "model": "gemini-pro",  // or "gpt-4", "gpt-3.5-turbo"
  "messages": [
    {"role": "user", "content": "Your prompt here"}
  ],
  "temperature": 0.7,  // optional, default: 0.7
  "max_tokens": 1000,  // optional
  "user_id": "user@example.com"  // optional, for billing tracking
}
```

**Response:**

```json
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1234567890,
  "model": "gemini-pro",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "AI response here..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 15,
    "completion_tokens": 25,
    "total_tokens": 40
  }
}
```

#### `GET /health`

Health check endpoint.

**Response:**

```json
{
  "status": "healthy"
}
```

## Model Mapping

The service automatically maps OpenAI model names to Gemini models:

| Requested Model | Gemini Model      |
|----------------|-------------------|
| `gpt-3.5-turbo`| `gemini-1.5-flash`|
| `gpt-4`        | `gemini-1.5-pro`  |
| `gemini-pro`   | `gemini-1.5-pro`  |
| `gemini-flash` | `gemini-1.5-flash`|

This allows Lotti to use standard OpenAI client libraries while benefiting from Gemini's capabilities.

## Billing & Usage Tracking

### Phase 1 (Current): Logging

The service currently **logs** all billing information to the console:

```
2024-11-26 10:30:45 - src.services.billing_service - INFO - 💰 BILLING | User: alice@example.com | Model: gemini-pro | Tokens: 150 input + 300 output = 450 total | Cost: $0.000225 USD | Request ID: req-abc123
```

Each log entry includes:
- User ID
- Model used
- Token counts (input, output, total)
- Estimated cost in USD
- Unique request ID for tracking

### Pricing

Current pricing (based on Gemini Pro):
- Input tokens: $0.00025 per 1,000 tokens
- Output tokens: $0.0005 per 1,000 tokens

Example costs:
- 1,000 input + 1,000 output tokens = $0.00075
- 100 input + 50 output tokens = $0.00005
- 5,000 input + 2,000 output tokens = $0.00225

### Phase 2 (Future): Actual Billing

In Phase 2, the service will integrate with the Credits Service to automatically bill users:

```python
# Future implementation
async with httpx.AsyncClient() as client:
    await client.post(
        f"{CREDITS_SERVICE_URL}/api/v1/bill",
        json={
            "user_id": metadata.user_id,
            "amount": float(metadata.estimated_cost_usd),
            "description": f"{metadata.model} - {metadata.total_tokens} tokens",
        },
    )
```

## Docker Deployment

### Build and run with Docker Compose

```bash
# Build the image
make docker-build

# Start the service
make docker-up

# View logs
make docker-logs

# Stop the service
make docker-down
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GEMINI_API_KEY` | *required* | Google Gemini API key |
| `PORT` | `8002` | Service port |
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |
| `CORS_ALLOWED_ORIGINS` | `http://localhost:3000,http://localhost:8080` | Comma-separated list of allowed CORS origins |

## Development

### Project Structure

```text
services/ai-proxy-service/
├── src/
│   ├── core/                    # Domain models and interfaces
│   │   ├── models.py           # Request/response models
│   │   ├── interfaces.py       # Service interfaces
│   │   ├── exceptions.py       # Custom exceptions
│   │   └── constants.py        # Constants (pricing, model mappings)
│   ├── services/               # Business logic
│   │   ├── gemini_client.py    # Gemini API client
│   │   └── billing_service.py  # Billing/cost calculation
│   ├── api/                    # HTTP API layer
│   │   └── routes.py           # FastAPI routes
│   ├── container.py            # Dependency injection
│   └── main.py                 # Application entry point
├── tests/
│   ├── unit/                   # Unit tests
│   └── integration/            # Integration tests
├── Dockerfile                  # Docker build config
├── docker-compose.yml          # Docker Compose config
├── requirements.txt            # Python dependencies
└── README.md                   # This file
```

### Running Tests

```bash
# Run all tests
make test

# Run unit tests only
make test-unit

# Run integration tests only (requires GEMINI_API_KEY)
make test-integration

# Run with coverage report
make test-coverage
```

**Note:** Integration tests require a valid `GEMINI_API_KEY` environment variable.

### Code Quality

Follow the Lotti project conventions:
- Type hints for all functions
- Docstrings for classes and methods
- Clean architecture with separation of concerns
- Interface-based design for testability

## Integration with Lotti App

### Lotti Configuration

Configure Lotti to use the AI Proxy instead of direct Gemini access:

```dart
// In your Lotti Flutter app config
const String aiEndpoint = 'http://localhost:8002/v1/chat/completions';
const String aiApiKey = 'dummy_key_ignored';  // Proxy ignores this
```

### Example Usage (Flutter/Dart)

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String> generateAIResponse(String prompt, String userId) async {
  final response = await http.post(
    Uri.parse('http://localhost:8002/v1/chat/completions'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'model': 'gpt-4',  // Will be mapped to gemini-1.5-pro
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'user_id': userId,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  } else {
    throw Exception('Failed to generate AI response');
  }
}
```

## Troubleshooting

### "GEMINI_API_KEY environment variable is required"

Make sure you've created a `.env` file with your Gemini API key:

```bash
cp .env.example .env
# Edit .env and add your key
```

### CORS errors from Lotti app

Update the `CORS_ALLOWED_ORIGINS` environment variable to include your Lotti app's origin:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,https://app.lotti.com
```

### "No module named 'google.generativeai'"

Install dependencies:

```bash
make install
```

## Future Enhancements

### Phase 2: Credits Service Integration
- Automatic billing via Credits Service
- Pre-flight balance checks
- Insufficient balance handling
- Transaction history

### Phase 3: Multi-Provider Support
- Support for OpenAI, Anthropic, etc.
- Provider selection per request
- Fallback mechanisms
- Cost optimization

### Phase 4: Advanced Features
- Request caching
- Rate limiting per user
- Usage analytics
- Cost budgets and alerts

## Contributing

Follow the Lotti project contribution guidelines. Ensure:
1. All tests pass (`make test`)
2. Code is properly typed
3. Documentation is updated

## License

Part of the Lotti project. See main project LICENSE.
