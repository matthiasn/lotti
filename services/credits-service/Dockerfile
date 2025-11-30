# ---- Build Stage ----
FROM python:3.13-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies as wheels
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


# ---- Final Stage ----
FROM python:3.13-slim

WORKDIR /app

# Create a non-root user to run the application
RUN useradd --create-home appuser

# Copy installed dependencies from the builder stage
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/*

# Copy application code
COPY --chown=appuser:appuser src/ ./src/

USER appuser

# Expose port
EXPOSE 8001

# Run the application
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8001"]
