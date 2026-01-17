#!/bin/bash
# Start Voxtral Local Service

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

# Check Python version (requires <3.14 for mistral-common)
PYTHON_VERSION=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PYTHON_MAJOR=$(python -c "import sys; print(sys.version_info.major)")
PYTHON_MINOR=$(python -c "import sys; print(sys.version_info.minor)")

if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 14 ]; then
    echo "WARNING: Python $PYTHON_VERSION detected. Voxtral requires Python <3.14 for mistral-common."
    echo "Please create a virtual environment with Python 3.13:"
    echo "  python3.13 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
    exit 1
fi
echo "  Python: $PYTHON_VERSION"

# Start the server
# Convert LOG_LEVEL to lowercase for uvicorn
LOG_LEVEL_LOWER=$(echo "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')

python -m uvicorn main:app \
    --host "$HOST" \
    --port "$PORT" \
    --log-level "$LOG_LEVEL_LOWER"
