# Stage 1: Build dependencies
FROM python:3.10-slim-bullseye as builder

WORKDIR /app

# Install build-time dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    libcairo2-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install Python requirements
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Final runtime image
FROM python:3.10-slim-bullseye

WORKDIR /app

# Install only the runtime libraries needed for Horilla's document generation
RUN apt-get update && apt-get install -y \
    libcairo2 \
    postgresql-client \
    gettext \
    && rm -rf /var/lib/apt/lists/*

# Copy installed Python packages from builder stage
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

# Copy project files
COPY . .

# Set environment variables for Railway
ENV PYTHONUNBUFFERED=1
ENV PORT=8000

# Compile translations and breadcrumbs (required for Horilla)
RUN python manage.py compilemessages

# Railway provides the PORT env var; we must bind to 0.0.0.0
# Using Gunicorn for production instead of 'runserver'
CMD ["sh", "-c", "python manage.py migrate && gunicorn horilla.wsgi:application --bind 0.0.0.0:${PORT}"]
