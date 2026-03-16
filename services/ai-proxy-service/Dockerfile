# Multi-stage build for AI Proxy Service
FROM python:3.13-slim AS builder

# Set working directory
WORKDIR /app

# Copy requirements
COPY ai-proxy-service/requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Final stage
FROM python:3.13-slim

# Create non-root user
RUN useradd -m -u 1000 appuser

# Set working directory
WORKDIR /app

# Copy dependencies from builder
COPY --from=builder /root/.local /home/appuser/.local

# Create data directory for SQLite databases (usage log, pricing)
RUN mkdir -p /app/data && chown appuser:appuser /app/data

# Copy application code and shared modules
COPY ai-proxy-service/src/ ./src/
COPY shared/ ./shared/

# Set environment variables
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8002

# Run the application
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8002"]
