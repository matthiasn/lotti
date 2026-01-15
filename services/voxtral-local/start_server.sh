#!/bin/bash
# Start Voxtral Local Service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables if .env exists
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Default values
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-11344}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

echo "Starting Voxtral Local Service..."
echo "  Host: $HOST"
echo "  Port: $PORT"
echo "  Log Level: $LOG_LEVEL"

# Check if virtual environment exists
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -d ".venv" ]; then
    source .venv/bin/activate
fi

# Start the server
# Convert LOG_LEVEL to lowercase for uvicorn
LOG_LEVEL_LOWER=$(echo "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')

python -m uvicorn main:app \
    --host "$HOST" \
    --port "$PORT" \
    --log-level "$LOG_LEVEL_LOWER"
