# AI Proxy Service

An OpenAI-compatible proxy service that forwards AI requests to Google Gemini and tracks billing information.

## Overview

This service acts as a middleware between the Lotti application and AI providers (currently Google Gemini). It provides:

- **OpenAI-compatible API**: Use standard OpenAI client libraries to interact with Gemini (non-streaming JSON or SSE streaming)
- **API Key Authentication**: Validates client keys (`API_KEYS`) and admin keys (`ADMIN_API_KEYS`) on protected paths
- **Rate Limiting**: Per-IP rate limiting via slowapi (30/min on chat completions, configurable default)
- **Request Tracing**: Request-ID middleware for correlating logs across a request
- **Usage Tracking**: Logs token usage and costs, and persists per-request usage to SQLite with retention
- **Metrics**: In-memory metrics collector exposed at `/metrics`
- **Pricing Management**: SQLite-backed, admin-editable pricing served via `/v1/pricing`
- **Billing**: Logs billing (Phase 1) and optionally bills the Credits Service when configured (Phase 2)
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
         │ Authorization: Bearer <API_KEYS>
         │ {"model": "gpt-4", "messages": [...]}
         ↓
┌─────────────────────────────────────────┐
│  AI Proxy Service (FastAPI)             │
│  ─────────────────────────────────     │
│  Middleware (request order):            │
│  request-ID → API-key auth → CORS       │
│  Route: rate limit (30/min)             │
│  1. Map model (gpt-4 → gemini-2.5-pro)  │
│  2. Forward to Gemini (stream or not)   │
│  3. Calculate cost (PricingService)     │
│  4. Log billing (+ Phase 2 if enabled)  │
│  5. Persist usage (SQLite) + metrics    │
│  6. Return OpenAI-format resp / SSE     │
└────┬────────────────────────────────────┘
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

# Chat completion (requires a valid API key from API_KEYS)
curl -X POST http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
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

All paths except `/health`, `/metrics`, `/docs`, `/openapi.json`, and `/redoc`
require an `Authorization: Bearer <api_key>` header (validated against `API_KEYS`).
The `/v1/pricing` and `/v1/usage` paths additionally require an admin key from
`ADMIN_API_KEYS`.

#### `POST /v1/chat/completions`

OpenAI-compatible chat completions endpoint. Rate limited to 30 requests per
minute per IP.

**Request:**

```json
{
  "model": "gemini-pro",  // or "gpt-4", "gpt-3.5-turbo"
  "messages": [
    {"role": "user", "content": "Your prompt here"}
  ],
  "temperature": 0.7,  // optional, default: 0.7
  "max_tokens": 1000,  // optional
  "stream": false,  // optional, default: false
  "user_id": "user@example.com"  // optional, for billing tracking
}
```

When `stream` is `true`, the endpoint returns a `text/event-stream` of
OpenAI-style `chat.completion.chunk` SSE events terminated by `data: [DONE]`
instead of the JSON body below.

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

Health check endpoint (auth-exempt).

**Response:**

```json
{
  "status": "healthy"
}
```

#### `GET /metrics`

Returns the in-memory metrics collected per request (request counts and success
rates, token usage, billing totals, and performance metrics). Auth-exempt; should
be restricted to internal networks in production.

#### Usage endpoints (admin key required)

- `GET /v1/usage/user/{user_id}` — paginated usage history for a user
  (`page`, `page_size`; `page_size` capped at 100).
- `GET /v1/usage/user/{user_id}/summary` — aggregated usage summary for a user.
- `GET /v1/usage/summary` — system-wide usage summary.

#### Pricing endpoints (admin key required)

- `GET /v1/pricing` — list all model pricing.
- `PUT /v1/pricing/{model_id}` — update pricing for an existing model
  (404 if the model is unknown).
- `POST /v1/pricing` — create pricing for a new model (409 if it already exists).

## Model Mapping

The service automatically maps OpenAI model names to Gemini models:

| Requested Model | Gemini Model      |
|----------------|-------------------|
| `gpt-3.5-turbo`| `gemini-2.5-flash`|
| `gpt-4`        | `gemini-2.5-pro`  |
| `gemini-pro`   | `gemini-2.5-pro`  |
| `gemini-flash` | `gemini-2.5-flash`|

This allows Lotti to use standard OpenAI client libraries while benefiting from Gemini's capabilities.

## Billing & Usage Tracking

### Phase 1 (always on): Logging

The service always **logs** billing information to the console:

```
2024-11-26 10:30:45 - src.services.billing_service - INFO - 💰 BILLING | User: alice@example.com | Model: gemini-pro | Tokens: 150 input + 300 output = 450 total | Cost: $0.003188 USD | Request ID: req-abc123
```

Each log entry includes:
- User ID
- Model used
- Token counts (input, output, total)
- Estimated cost in USD
- Unique request ID for tracking

### Pricing

Pricing is served by the SQLite-backed `PricingService` (admin-editable via the
`/v1/pricing` endpoints, seeded from the constants below) with a fallback to the
constant table in `src/core/constants.py`. Costs are computed as
`(tokens / 1000) * price_per_1k` for input and output tokens.

| Model              | Input (per 1K tokens) | Output (per 1K tokens) |
|--------------------|-----------------------|------------------------|
| `gemini-2.5-pro`   | $0.00125              | $0.01                  |
| `gemini-2.5-flash` | $0.0003               | $0.0025                |

Unknown models fall back to the default pricing ($0.00125 input / $0.01 output
per 1K tokens).

Example costs for `gemini-2.5-flash`:
- 1,000 input + 1,000 output tokens = $0.0028
- 100 input + 50 output tokens = $0.000155
- 5,000 input + 2,000 output tokens = $0.0065

### Phase 2 (Implemented, gated): Actual Billing

Phase 2 billing is implemented in `BillingService.log_billing` and is enabled
automatically when both `CREDITS_SERVICE_URL` and `CREDITS_SERVICE_API_KEY` are
set (`phase2_enabled`). When enabled, after logging, the service posts each charge
to the Credits Service and handles insufficient balance (`402`), timeouts, and
request errors by raising an `AIProviderException`:

```python
# src/services/billing_service.py (Phase 2, when phase2_enabled)
async with httpx.AsyncClient(timeout=10.0) as client:
    response = await client.post(
        f"{CREDITS_SERVICE_URL}/api/v1/bill",
        json={
            "user_id": metadata.user_id,
            "amount": float(metadata.estimated_cost_usd),
            "description": f"{metadata.model} - {metadata.total_tokens} tokens (req: {metadata.request_id})",
        },
        headers={"Authorization": f"Bearer {CREDITS_SERVICE_API_KEY}"},
    )
    if response.status_code == 402:
        raise AIProviderException("Insufficient balance...")
```

When either env var is unset, Phase 2 is disabled and the service logs billing
information only (Phase 1).

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
| `API_KEYS` | *(empty)* | Comma-separated client API keys. If empty, all requests to protected paths are rejected (401/503). |
| `ADMIN_API_KEYS` | *(empty)* | Comma-separated admin API keys required for `/v1/pricing` and `/v1/usage` paths. |
| `PORT` | `8002` | Service port |
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |
| `CORS_ALLOWED_ORIGINS` | `http://localhost:3000,http://localhost:8080,http://localhost:5173` | Comma-separated list of allowed CORS origins |
| `RATE_LIMIT_ENABLED` | `true` | Enable/disable IP rate limiting. |
| `RATE_LIMIT_PER_MINUTE` | `60` | Default per-IP requests per minute (chat completions are additionally capped at 30/min). |
| `CREDITS_SERVICE_URL` | *(empty)* | Credits Service base URL. Set together with `CREDITS_SERVICE_API_KEY` to enable Phase 2 billing. |
| `CREDITS_SERVICE_API_KEY` | *(empty)* | Bearer token for the Credits Service (Phase 2 billing). |
| `USAGE_LOG_RETENTION_DAYS` | `90` | Retention window for persisted usage log entries. |

## Development

### Project Structure

```text
services/ai-proxy-service/
├── src/
│   ├── core/                    # Domain models and interfaces
│   │   ├── models.py           # Request/response models
│   │   ├── interfaces.py       # Service interfaces
│   │   ├── exceptions.py       # Custom exceptions
│   │   ├── metrics.py          # In-memory metrics collector
│   │   └── constants.py        # Constants (pricing, model mappings)
│   ├── middleware/             # ASGI middleware
│   │   ├── rate_limit.py       # slowapi rate limiter
│   │   └── request_id.py       # Request-ID tracing middleware
│   ├── services/               # Business logic
│   │   ├── gemini_client.py    # Gemini API client
│   │   ├── billing_service.py  # Billing/cost calculation + Phase 2
│   │   ├── pricing_service.py  # SQLite-backed pricing service
│   │   └── usage_log_service.py # SQLite-backed usage logging
│   ├── api/                    # HTTP API layer
│   │   └── routes.py           # FastAPI routes
│   ├── container.py            # Dependency injection
│   └── main.py                 # Application entry point
│
│   # API-key auth middleware lives in services/shared/auth
│   # (imported as `shared.auth`, copied into the image by the Dockerfile)
├── tests/
│   ├── unit/                   # Unit tests
│   └── integration/            # Integration tests
├── Dockerfile                  # Docker build config
├── docker-compose.yml          # Docker Compose config
├── requirements.txt            # Python dependencies
└── README.md                   # This file
```

### Running Tests

`make install` installs runtime dependencies only. The test commands below
require the dev/test tools (pytest, coverage), so install them first:

```bash
make install-dev
```

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
// Must be one of the keys configured in the proxy's API_KEYS env var.
// The proxy requires "Authorization: Bearer <apiKey>" on /v1/chat/completions.
const String aiApiKey = 'your_api_key';
```

### Example Usage (Flutter/Dart)

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String> generateAIResponse(String prompt, String userId) async {
  final response = await http.post(
    Uri.parse('http://localhost:8002/v1/chat/completions'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer your_api_key', // must match a key in API_KEYS
    },
    body: jsonEncode({
      'model': 'gpt-4',  // Will be mapped to gemini-2.5-pro
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

> Phase 2 Credits Service billing (automatic billing and insufficient-balance
> handling) is already implemented — see [Billing & Usage Tracking](#billing--usage-tracking).

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
