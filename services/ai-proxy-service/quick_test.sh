#!/bin/bash

echo "🧪 AI Proxy Quick Test Script"
echo "=============================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cp .env.example .env
fi

# Check if GEMINI_API_KEY is set in .env
if ! grep -q "GEMINI_API_KEY=AIza" .env 2>/dev/null; then
    echo "⚠️  GEMINI_API_KEY not found in .env file"
    echo ""
    echo "Please add your Gemini API key to the .env file:"
    echo "  nano .env"
    echo ""
    echo "Or set it now:"
    read -p "Enter your Gemini API key (or press Enter to skip): " gemini_key

    if [ -n "$gemini_key" ]; then
        # Update .env file
        sed -i.bak "s/^GEMINI_API_KEY=.*/GEMINI_API_KEY=$gemini_key/" .env
        echo "✅ API key added to .env"
    else
        echo "⏭️  Skipping - you can add it later"
        echo "   Edit .env and add: GEMINI_API_KEY=your_key_here"
        exit 1
    fi
fi

echo ""
echo "✅ Environment configured"
echo ""

# Check if venv exists
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate venv and install dependencies
echo "📦 Installing dependencies..."
source venv/bin/activate
pip install -q -r requirements.txt

echo ""
echo "🚀 Starting AI Proxy Service..."
echo "   (Press Ctrl+C to stop)"
echo ""

# Start the service
python -m uvicorn src.main:app --host 0.0.0.0 --port 8002
