FROM python:3.13-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/

# Expose port
EXPOSE 8001

# Run the application
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8001"]
