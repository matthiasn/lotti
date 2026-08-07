# ---- Build Stage ----
FROM python:3.13-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies as wheels
COPY matrix-provisioning-service/requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


# ---- Final Stage ----
FROM python:3.13-slim

WORKDIR /app

# Create a non-root user to run the application
RUN useradd --create-home appuser

# Copy installed dependencies from the builder stage
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/*

# Create data directory for the SQLite provisioning database
RUN mkdir -p /app/data && chown appuser:appuser /app/data

# Copy application code and shared modules
COPY --chown=appuser:appuser matrix-provisioning-service/src/ ./src/
COPY --chown=appuser:appuser shared/ ./shared/

USER appuser

EXPOSE 8003

# Shell form so ${PORT} is expanded at runtime. The exec form would pass the
# literal string and the container would ignore the documented PORT setting,
# binding 8003 whatever the deployment asked for. `exec` keeps uvicorn as PID 1
# so it still receives SIGTERM on shutdown.
CMD exec uvicorn src.main:app --host 0.0.0.0 --port "${PORT:-8003}"
