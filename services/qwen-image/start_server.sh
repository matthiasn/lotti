#!/bin/bash
# Start Qwen Image Service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables if .env exists
# Using set -a to auto-export and source to preserve quoted values/special chars
if [ -f .env ]; then
    set -a
    # shellcheck source=/dev/null
    source .env
    set +a
fi

# Default values
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-11345}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

echo "Starting Qwen Image Service..."
echo "  Host: $HOST"
echo "  Port: $PORT"
echo "  Log Level: $LOG_LEVEL"

# Check if virtual environment exists
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -d ".venv" ]; then
    source .venv/bin/activate
fi

# Check Python version
PYTHON_VERSION=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "  Python: $PYTHON_VERSION"

# Start the server
# Convert LOG_LEVEL to lowercase for uvicorn
LOG_LEVEL_LOWER=$(echo "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')

python -m uvicorn main:app \
    --host "$HOST" \
    --port "$PORT" \
    --log-level "$LOG_LEVEL_LOWER"
