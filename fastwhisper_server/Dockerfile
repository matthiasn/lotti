# Use Python 3.9 as base image
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy server code
COPY fastwhisper_server.py .

# Set environment variables
ENV KMP_DUPLICATE_LIB_OK=TRUE
ENV ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8000

# Expose the port the server runs on
EXPOSE 8000

# Command to run the server
CMD ["python", "fastwhisper_server.py"] 