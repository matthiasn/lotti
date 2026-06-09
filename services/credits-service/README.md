# Credits Service

A ledger-based service for managing user credits. Balances and transfers are held in TigerBeetle (the ledger), while a user registry and a transaction history are persisted in two SQLite databases under `data/`.

## Overview

This service provides account management for user credits in Lotti application. It acts as a financial ledger system where users can:
- Create accounts
- Top-up credits (add money)
- Get balance
- Bill charges against their account

## Architecture

Built following the modular architecture pattern used in the Lotti project:

```text
src/
├── core/                    # Domain models and interfaces
│   ├── models.py           # Request/response models
│   ├── interfaces.py       # Service interfaces
│   ├── exceptions.py       # Custom exceptions
│   └── constants.py        # Constants
├── services/               # Business logic implementations
│   ├── tigerbeetle_client.py        # TigerBeetle client
│   ├── account_service.py           # Account management
│   ├── balance_service.py           # Balance queries
│   ├── billing_service.py           # Top-up and billing
│   ├── user_registry_service.py     # SQLite-backed user registry (data/user_registry.db)
│   └── transaction_log_service.py   # SQLite-backed transaction log (data/transaction_log.db)
├── api/                    # HTTP API layer
│   └── routes.py           # FastAPI routes
├── container.py            # Dependency injection
└── main.py                 # Application entry point
```

API-key authentication is enforced by `APIKeyAuthMiddleware`, sourced from the
shared `services/shared/auth` package and registered in `main.py`.

## Requirements

- Python 3.13+
- Docker (for TigerBeetle)
- Docker Compose

## Quick Start

### 1. Set up virtual environment

```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install dependencies

```bash
make install-dev
```

### 3. Start services with Docker Compose

```bash
make docker-up
```

This will start:
- TigerBeetle database on port 3000
- Credits service on port 8001

### 4. Test the API

Every endpoint requires authentication (see [Authentication](#authentication)).
With `API_KEYS=dev-key` configured, the health check is:

```bash
curl http://localhost:8001/api/v1/health \
  -H "Authorization: Bearer dev-key"
```

## Authentication

All requests are gated by `APIKeyAuthMiddleware` (registered in `main.py`,
implemented in `services/shared/auth/middleware.py`). Each request must carry an
`Authorization: Bearer <api_key>` header.

- API keys come from the `API_KEYS` environment variable (comma-separated). If
  `API_KEYS` is unset, every **non-admin** authenticated request is rejected
  (`503` once a Bearer header is present); admin endpoints are still reachable
  with a valid `ADMIN_API_KEYS` key, because the admin-path check runs before the
  regular-key check.
- Missing `Authorization` header → `401`; malformed header → `401`; unknown key → `403`.
- Admin endpoints under `/api/v1/users` require a key from `ADMIN_API_KEYS`
  (comma-separated). If `ADMIN_API_KEYS` is unset, those endpoints return `503`;
  a non-admin key returns `403`.
- The middleware's exempt-path list (`/health`, `/docs`, `/openapi.json`,
  `/redoc`) is matched against the full request path. Because the router is
  mounted under `/api/v1`, the live health path is `/api/v1/health`, which is
  **not** exempt and therefore also requires an `Authorization` header.

## API Endpoints

All endpoints are under the `/api/v1` prefix and require an
`Authorization: Bearer <api_key>` header (see [Authentication](#authentication)).

### Create Account

```bash
POST /api/v1/accounts
{
  "user_id": "john@example.com",
  "initial_balance": 0.00
}
```

Response:
```json
{
  "account_id": 123456789,
  "user_id": "john@example.com",
  "balance": 0.00
}
```

### Get Balance

```bash
POST /api/v1/balance
{
  "user_id": "john@example.com"
}
```

Response:
```json
{
  "user_id": "john@example.com",
  "balance": 100.00
}
```

### Top-Up Credits

```bash
POST /api/v1/topup
{
  "user_id": "john@example.com",
  "amount": 100.00
}
```

Response:
```json
{
  "user_id": "john@example.com",
  "amount_added": 100.00,
  "new_balance": 100.00
}
```

### Bill Account

```bash
POST /api/v1/bill
{
  "user_id": "john@example.com",
  "amount": 0.25,
  "description": "Gemini API call"
}
```

Response:
```json
{
  "user_id": "john@example.com",
  "amount_billed": 0.25,
  "new_balance": 99.75
}
```

### List Users (admin)

Requires an admin key (`ADMIN_API_KEYS`). Pagination params: `page` (default 1)
and `page_size` (default 20, clamped to 1–100).

```bash
GET /api/v1/users?page=1&page_size=20
```

Response:
```json
{
  "users": [
    {
      "user_id": "john@example.com",
      "display_name": null,
      "created_at": "2025-01-01T00:00:00+00:00",
      "balance": 99.75
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 20
}
```

### Get User (admin)

Requires an admin key. Returns `404` if the user is not registered.

```bash
GET /api/v1/users/{user_id}
```

Response:
```json
{
  "user_id": "john@example.com",
  "display_name": null,
  "created_at": "2025-01-01T00:00:00+00:00",
  "balance": 99.75
}
```

### Get Transactions (admin)

Requires an admin key. Returns the user's top-up/bill history (recorded by the
SQLite transaction log) with `page`/`page_size` pagination. Returns `404` if the
user is not registered.

```bash
GET /api/v1/users/{user_id}/transactions?page=1&page_size=20
```

Response:
```json
{
  "transactions": [
    {
      "id": 1,
      "user_id": "john@example.com",
      "type": "bill",
      "amount": 0.25,
      "description": "Gemini API call",
      "balance_after": 99.75,
      "created_at": "2025-01-01T00:00:00+00:00"
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 20
}
```

## Development

### Run tests

```bash
# All tests
make test

# Unit tests only
make test-unit

# Integration tests only
make test-integration
```

### Code quality checks

```bash
# Run all checks
make check-all

# Individual checks
make lint
make format
make type-check
make security-scan
```

### Run locally (without Docker)

First, start TigerBeetle manually, then:

```bash
make run
```

Or with auto-reload:

```bash
make run-dev
```

## Testing Strategy

### End-to-End Test Scenario

The complete test flow (`tests/integration/test_e2e_flow.py`):

1. **Create account** for user → Balance: $0
2. **Top-up** $100 → Balance: $100
3. **Get balance** → Verify $100
4. **Bill** $0.25 for API call → Balance: $99.75
5. **Get balance** → Verify $99.75

Run it:
```bash
make test-integration
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TIGERBEETLE_CLUSTER_ID` | `0` | TigerBeetle cluster ID |
| `TIGERBEETLE_HOST` | `localhost` | TigerBeetle host |
| `TIGERBEETLE_PORT` | `3000` | TigerBeetle port |
| `PORT` | `8001` | Service port |
| `LOG_LEVEL` | `INFO` | Logging level |
| `CORS_ALLOWED_ORIGINS` | `http://localhost:3000,http://localhost:5173` | Comma-separated list of allowed CORS origins |
| `API_KEYS` | _(empty)_ | Comma-separated API keys. Required: when empty, every non-admin request is rejected with `503` (admin endpoints still work with a valid `ADMIN_API_KEYS` key) |
| `ADMIN_API_KEYS` | _(empty)_ | Comma-separated admin API keys required for the `/api/v1/users*` endpoints |

## Docker Commands

```bash
# Build images
make docker-build

# Start services
make docker-up

# View logs
make docker-logs

# Stop services
make docker-down

# Clean up volumes
make docker-clean
```

## TigerBeetle

This service uses [TigerBeetle](https://tigerbeetle.com/) as the ledger database. TigerBeetle is specifically designed for financial transactions with:

- **ACID compliance**: Ensures data consistency
- **Double-entry accounting**: Built-in ledger semantics
- **High performance**: Optimized for financial workloads
- **Safety**: Prevents common accounting errors

### Why TigerBeetle?

- Designed specifically for ledger/accounting use cases
- Built-in account and transfer primitives
- Prevents overdrafts and maintains balance integrity
- Handles concurrent transactions safely

## Future Enhancements

Phase 2 will add:
- Proxy functionality for AI provider calls (Gemini, OpenAI, Anthropic)
- Automatic billing based on API usage
- Multiple currency support
- Usage analytics

## Contributing

Follow the Lotti project contribution guidelines. Ensure:
1. All tests pass (`make test`)
2. Code passes linting (`make check-all`)
3. Type hints are included
4. Documentation is updated

## License

Part of the Lotti project. See main project LICENSE.
