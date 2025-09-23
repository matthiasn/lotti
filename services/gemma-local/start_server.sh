#!/bin/bash

# Gemma 3N Server Startup Script
# This script starts the server and keeps it running for app integration

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎯 Starting Gemma 3N Service for App Integration${NC}"
echo "================================================="

# Kill any existing servers
echo -e "${BLUE}🧹 Cleaning up existing servers...${NC}"
lsof -i :11343 | grep LISTEN | awk '{print $2}' | xargs kill -9 2>/dev/null || true
sleep 1

# Start server
echo -e "${BLUE}🚀 Starting Gemma 3N service on localhost:11343...${NC}"

# Load optional .env next to this script
if [ -f .env ]; then
  echo -e "${BLUE}📦 Loading .env from $(pwd)/.env${NC}"
  set -a; source .env; set +a
fi

# Defaults for perf/logging can be overridden by the environment
export LOG_LEVEL=${LOG_LEVEL:-INFO}
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-8}
export VECLIB_MAXIMUM_THREADS=${VECLIB_MAXIMUM_THREADS:-8}
export MKL_NUM_THREADS=${MKL_NUM_THREADS:-8}
export AUDIO_OVERLAP_SECONDS=${AUDIO_OVERLAP_SECONDS:-0.5}
export LOG_TO_STDOUT=${LOG_TO_STDOUT:-0}
export ATTN_IMPL=${ATTN_IMPL:-sdpa}

echo -e "${BLUE}⚙️  Env: LOG_LEVEL=$LOG_LEVEL OMP_NUM_THREADS=$OMP_NUM_THREADS VECLIB_MAXIMUM_THREADS=$VECLIB_MAXIMUM_THREADS MKL_NUM_THREADS=$MKL_NUM_THREADS AUDIO_OVERLAP_SECONDS=$AUDIO_OVERLAP_SECONDS LOG_TO_STDOUT=$LOG_TO_STDOUT ATTN_IMPL=$ATTN_IMPL${NC}"

source venv/bin/activate
python main.py &
SERVER_PID=$!

# Wait for server to be ready
echo -e "${BLUE}⏳ Waiting for server to initialize...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:11343/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Server ready on http://localhost:11343${NC}"
        echo -e "${GREEN}✅ Health endpoint: http://localhost:11343/health${NC}"
        echo -e "${GREEN}✅ Models endpoint: http://localhost:11343/v1/models${NC}"
        echo -e "${GREEN}✅ Chat completions: http://localhost:11343/v1/chat/completions${NC}"
        echo ""
        echo -e "${BLUE}🎙️ Server is ready for audio transcription requests from the app!${NC}"
        echo -e "${BLUE}📱 You can now use Gemma 3n provider in the Lotti app${NC}"
        echo ""
        echo -e "${RED}💡 To stop the server, press Ctrl+C or run: kill $SERVER_PID${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Server failed to start${NC}"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    sleep 2
done

# Keep server running
echo -e "${BLUE}🔄 Server running with PID: $SERVER_PID${NC}"
echo -e "${BLUE}🔄 Logs are being written to console...${NC}"
echo ""

# Wait for server process
wait $SERVER_PID
