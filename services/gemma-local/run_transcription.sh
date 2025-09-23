#!/bin/bash

# Clean Gemma 3N Transcription Runner
# This script starts the server and runs transcription

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎯 Gemma 3N Audio Transcription Service${NC}"
echo "========================================"

# Check if audio file provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Usage: $0 <audio_file>${NC}"
    echo "Example: $0 ~/Desktop/2minTest.m4a"
    exit 1
fi

AUDIO_FILE="$1"
if [ ! -f "$AUDIO_FILE" ]; then
    echo -e "${RED}Error: Audio file '$AUDIO_FILE' not found${NC}"
    exit 1
fi

# Kill any existing servers
echo -e "${BLUE}🧹 Cleaning up existing servers...${NC}"
lsof -i :11343 | grep LISTEN | awk '{print $2}' | xargs kill -9 2>/dev/null || true
sleep 2

# Start server in background
echo -e "${BLUE}🚀 Starting Gemma 3N service...${NC}"

# Load optional .env next to this script
if [ -f .env ]; then
  echo -e "${BLUE}📦 Loading .env from $(pwd)/.env${NC}"
  set -a; source .env; set +a
fi

# Defaults for perf/logging (can override via env)
export LOG_LEVEL=${LOG_LEVEL:-INFO}
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-8}
export VECLIB_MAXIMUM_THREADS=${VECLIB_MAXIMUM_THREADS:-8}
export MKL_NUM_THREADS=${MKL_NUM_THREADS:-8}
export AUDIO_OVERLAP_SECONDS=${AUDIO_OVERLAP_SECONDS:-0.5}
export LOG_TO_STDOUT=${LOG_TO_STDOUT:-0}
export ATTN_IMPL=${ATTN_IMPL:-sdpa}
echo -e "${BLUE}⚙️  Env: LOG_LEVEL=$LOG_LEVEL OMP_NUM_THREADS=$OMP_NUM_THREADS VECLIB_MAXIMUM_THREADS=$VECLIB_MAXIMUM_THREADS MKL_NUM_THREADS=$MKL_NUM_THREADS AUDIO_OVERLAP_SECONDS=$AUDIO_OVERLAP_SECONDS LOG_TO_STDOUT=$LOG_TO_STDOUT ATTN_IMPL=$ATTN_IMPL${NC}"

source venv/bin/activate
python main.py > /tmp/gemma_server.log 2>&1 &
SERVER_PID=$!

# Wait for server to be ready
echo -e "${BLUE}⏳ Waiting for server to initialize...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:11343/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Server ready!${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Server failed to start${NC}"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    sleep 2
done

# Run transcription
echo -e "${BLUE}🎙️ Starting transcription of: $(basename "$AUDIO_FILE")${NC}"
echo -e "${BLUE}📊 Processing audio...${NC}"
echo ""

# Trap to ensure server cleanup on exit
trap 'kill $SERVER_PID 2>/dev/null || true' EXIT

# Run the transcription
python transcribe_utils_standalone.py "$AUDIO_FILE"

echo ""
echo -e "${GREEN}🎉 Transcription complete!${NC}"
echo -e "${BLUE}🛑 Stopping server...${NC}"
kill $SERVER_PID 2>/dev/null || true
