#!/bin/bash

# Gemma Local Service Setup Script
# Usage: HF_TOKEN=your_token_here ./setup.sh

set -e  # Exit on error

echo "🚀 Gemma Local Service Setup"
echo "============================"

# Check if HF_TOKEN is provided
if [ -z "$HF_TOKEN" ]; then
    echo "❌ Error: HuggingFace token not provided"
    echo ""
    echo "Please run the script with your HuggingFace token:"
    echo "  HF_TOKEN=hf_xxxxxxxxxxxx ./setup.sh"
    echo ""
    echo "To get a token:"
    echo "  1. Create account at: https://huggingface.co/join"
    echo "  2. Accept Gemma model at: https://huggingface.co/google/gemma-3n-E2B-it"
    echo "  3. Create token at: https://huggingface.co/settings/tokens"
    exit 1
fi

echo "✅ HuggingFace token provided"
echo ""

# Step 1: Install huggingface_hub and authenticate
echo "📦 Installing huggingface_hub..."
pip install -q huggingface_hub

echo "🔐 Authenticating with HuggingFace..."
python3 -c "from huggingface_hub import login; login(token='$HF_TOKEN', add_to_git_credential=True)"
if [ $? -eq 0 ]; then
    echo "✅ Successfully authenticated with HuggingFace"
else
    echo "❌ Failed to authenticate. Please check your token."
    exit 1
fi

# Step 2: Create virtual environment
echo ""
echo "🐍 Creating virtual environment..."
if [ -d "venv" ]; then
    echo "  Virtual environment already exists, skipping..."
else
    python3 -m venv venv
    echo "✅ Virtual environment created"
fi

# Step 3: Activate venv and install dependencies
echo ""
echo "📦 Installing dependencies..."
source venv/bin/activate
pip install -q -r requirements.txt
echo "✅ Dependencies installed"

# Step 4: Create .env file if it doesn't exist
echo ""
if [ -f ".env" ]; then
    echo "⚠️  .env file already exists, skipping..."
else
    echo "📝 Creating .env configuration file..."
    cat > .env << EOF
GEMMA_MODEL_ID=google/gemma-3n-E2B-it
DEFAULT_DEVICE=auto
USE_CPU_QUANTIZATION=false
MAX_AUDIO_SIZE_MB=100
LOG_LEVEL=INFO
PORT=11343
HOST=0.0.0.0
EOF
    echo "✅ Configuration file created"
fi

# Step 5: System info
echo ""
echo "📊 System Information:"
echo "  Platform: $(uname -s)"
echo "  Python: $(python3 --version)"
echo "  Memory: $([ "$(uname -s)" = "Darwin" ] && echo "$(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024 " GB"}' )" || free -h | grep Mem | awk '{print $2}')"

# Step 6: Check GPU availability
echo ""
echo "🎮 Checking GPU availability..."
python3 -c "
import torch
if torch.cuda.is_available():
    print('  ✅ CUDA GPU available')
    print(f'  GPU: {torch.cuda.get_device_name(0)}')
elif torch.backends.mps.is_available():
    print('  ✅ Apple Silicon MPS available')
else:
    print('  ℹ️  No GPU detected, will use CPU')
" 2>/dev/null || echo "  ℹ️  PyTorch not yet installed"

# Step 7: Instructions
echo ""
echo "✨ Setup complete!"
echo ""
echo "📚 Next steps:"
echo "  1. Activate the virtual environment:"
echo "     source venv/bin/activate"
echo ""
echo "  2. Run the service:"
echo "     python main.py"
echo ""
echo "  3. The model (~10.13GB) will download automatically on first use"
echo ""
echo "  4. Test the service:"
echo "     curl http://localhost:11343/health"
echo ""
echo "Optional: To pre-download the model now, run:"
echo "  source venv/bin/activate"
echo "  python -c \"from huggingface_hub import snapshot_download; print('Downloading model...'); snapshot_download('google/gemma-3n-E2B-it', cache_dir='.cache/models'); print('✅ Model downloaded!')\""