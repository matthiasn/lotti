# Lotti Customer Care Dashboard

A PoC management dashboard for customer care agents to view user details,
token usage, account balances, and model pricing.

## Quick Start (Local Development)

```bash
# Install dependencies
npm install

# Start dev server (requires credits-service on :8001 and ai-proxy on :8002)
npm run dev

# Open http://localhost:5173
```

## Quick Start (Docker Compose)

From the `services/` directory:

```bash
# Set your Gemini API key
export GEMINI_API_KEY=your-key-here

# Start all services
docker compose -f docker-compose.dashboard.yml up --build

# Dashboard at http://localhost:5173
```

## Architecture

```
Dashboard (:5173) ──┬── Credits Service (:8001) ── TigerBeetle
                    └── AI Proxy Service (:8002) ── Gemini API
```

The Vite dev server proxies `/api/*` to credits-service and `/v1/*` to
ai-proxy-service. In Docker, nginx handles the same routing.

## Pages

| Page | Route | Description |
|------|-------|-------------|
| Users | `/users` | Paginated list of all users with balances |
| User Detail | `/users/:id` | Balance, transactions, token usage charts, model breakdown |
| System Overview | `/overview` | System-wide stats and usage charts |
| Pricing | `/pricing` | View and edit model pricing ($/1K tokens) |

## Tech Stack

- React 18 + TypeScript
- Vite (build + dev server)
- Recharts (charts)
- React Router (navigation)
- Vitest + Testing Library (tests)

## Testing

```bash
npm test          # Run tests once
npm run test:watch # Watch mode
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VITE_API_KEY` | `dev-key` | API key for backend services |
