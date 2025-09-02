#!/bin/bash

# Gemma Local Service Setup Script

set -e

echo "🤖 Gemma Local Service Setup"
echo "=" | tr -c '\n' '=' | head -c 40
echo

# Check if Python 3.11+ is available
echo "Checking Python version..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
    echo "✓ Python $PYTHON_VERSION found"
    
    # Check if version is 3.11+
    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 11) else 1)"; then
        echo "✓ Python version is compatible"
    else
        echo "⚠ Python 3.11+ recommended for best performance"
    fi
else
    echo "❌ Python 3 not found. Please install Python 3.11+"
    exit 1
fi

# Check if pip is available
if command -v pip3 &> /dev/null; then
    echo "✓ pip3 found"
else
    echo "❌ pip3 not found. Please install pip"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment exists"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt

echo "✓ Dependencies installed"

# Check PyTorch installation
echo "Checking PyTorch installation..."
python3 -c "
import torch
print(f'✓ PyTorch version: {torch.__version__}')
if torch.cuda.is_available():
    print(f'✓ CUDA available: {torch.cuda.get_device_name(0)}')
elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
    print('✓ Apple MPS (Metal) available')
else:
    print('ℹ Using CPU (slower inference)')
"

echo
echo "🎉 Setup complete!"
echo
echo "To start the service:"
echo "  1. Activate virtual environment: source venv/bin/activate"
echo "  2. Run the service: python start.py"
echo
echo "Or use Docker:"
echo "  docker-compose up --build"
echo
echo "Service will be available at: http://localhost:8000"
echo "API docs: http://localhost:8000/docs"