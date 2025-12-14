# Base image
FROM python:3.11-slim

# Set environment
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

# Install system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m appuser

# Workdir
WORKDIR /app

# Copy requirements separately for better caching
COPY app/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy app
COPY app/ /app/

# Switch to non-root
USER appuser

# Expose port
EXPOSE 8080

# Healthcheck (container-level)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s CMD curl -f http://localhost:8080/healthz || exit 1

# Run via gunicorn (prod-ready)
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "main:app"]
