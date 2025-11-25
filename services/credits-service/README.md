# Credits Service

A ledger-based service for managing user credits using TigerBeetle as the database backend.

## Overview

This service provides account management for user credits in Lotti application. It acts as a financial ledger system where users can:
- Create accounts
- Top-up credits (add money)
- Get balance
- Bill charges against their account

## Architecture

Built following the modular architecture pattern used in the Lotti project:

```
src/
├── core/                    # Domain models and interfaces
│   ├── models.py           # Request/response models
│   ├── interfaces.py       # Service interfaces
│   ├── exceptions.py       # Custom exceptions
│   └── constants.py        # Constants
├── services/               # Business logic implementations
│   ├── tigerbeetle_client.py    # TigerBeetle client
│   ├── account_service.py       # Account management
│   ├── balance_service.py       # Balance queries
│   └── billing_service.py       # Top-up and billing
├── api/                    # HTTP API layer
│   └── routes.py           # FastAPI routes
├── container.py            # Dependency injection
└── main.py                 # Application entry point
```

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

Health check:
```bash
curl http://localhost:8001/api/v1/health
```

## API Endpoints

All endpoints are under `/api/v1` prefix.

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
- Transaction history
- Usage analytics

## Contributing

Follow the Lotti project contribution guidelines. Ensure:
1. All tests pass (`make test`)
2. Code passes linting (`make check-all`)
3. Type hints are included
4. Documentation is updated

## License

Part of the Lotti project. See main project LICENSE.
