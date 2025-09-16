#!/bin/bash

# Setup script for Gemma Audio Transcription Service

set -e

echo "==================================="
echo "Gemma Audio Transcription Setup"
echo "==================================="

# Check Python version
PYTHON_CMD=""
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "Error: Python not found. Please install Python 3.9 or higher."
    exit 1
fi

echo "Using Python: $($PYTHON_CMD --version)"

# Create virtual environment
echo "Creating virtual environment..."
$PYTHON_CMD -m venv venv

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

echo ""
echo "==================================="
echo "Setup complete!"
echo "==================================="
echo ""
echo "To start using the service:"
echo "1. Activate the virtual environment:"
echo "   source venv/bin/activate"
echo ""
echo "2. Start the service:"
echo "   python main.py"
echo ""
echo "3. Or specify a model variant:"
echo "   GEMMA_MODEL_VARIANT=E4B python main.py"
echo ""
echo "4. Run tests:"
echo "   python test_transcription.py --run-all"
echo ""