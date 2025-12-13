# 1. Use slim Python 3.10 base image
FROM python:3.10-slim

# 2. Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DATABASE_URL="" \
    DEBUG=False \
    SECRET_KEY=changeme \
    ALLOWED_HOSTS=*

# 3. Install system dependencies
# Includes fixes for common Python/Django packages (PostgreSQL, Pillow, WeasyPrint/Cairo)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        libjpeg-dev \
        zlib1g-dev \
        curl \
        netcat-openbsd \
        git \
        libcairo2-dev \
        pkg-config \
        libpango-1.0-0 \
        libpangoft2-1.0-0 \
        libgdk-pixbuf-2.0-0 \
        libffi-dev \
        shared-mime-info && \
    rm -rf /var/lib/apt/lists/*

# 4. Set work directory
WORKDIR /app

# 5. Copy only requirements first (for better layer caching)
COPY requirements.txt .

# 6. Upgrade pip and install Python dependencies
# Installs from requirements.txt + extras, including psycopg2-binary (avoids source build)
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir \
        uvicorn[standard] \
        psycopg2-binary \
        gunicorn

# 7. Now copy the rest of the application code
COPY . .

# 8. Create .env file from environment variables (at build time or runtime)
# Note: In production, better to pass these at runtime via docker-compose or orchestration
RUN echo "DATABASE_URL=$DATABASE_URL" > .env && \
    echo "DEBUG=$DEBUG" >> .env && \
    echo "SECRET_KEY=$SECRET_KEY" >> .env && \
    echo "ALLOWED_HOSTS=$ALLOWED_HOSTS" >> .env

# 9. Create entrypoint script
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'echo "Running database migrations..."' >> /entrypoint.sh && \
    echo 'python manage.py migrate --noinput' >> /entrypoint.sh && \
    echo 'echo "Collecting static files..."' >> /entrypoint.sh && \
    echo 'python manage.py collectstatic --noinput --clear' >> /entrypoint.sh && \
    echo 'exec "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# 10. Create non-root user for security
RUN useradd --create-home --uid 1000 appuser && \
    mkdir -p /app/staticfiles /app/media && \
    chown -R appuser:appuser /app /entrypoint.sh

# 11. Switch to non-root user
USER appuser

# 12. Expose port
EXPOSE 8000

# 13. Entry point and default command
ENTRYPOINT ["/entrypoint.sh"]

# Use gunicorn in production, uvicorn in development
# Override with docker run --cmd for dev
CMD ["gunicorn", "horilla.asgi:application", "--bind", "0.0.0.0:8000", "--workers", "3", "--worker-class", "uvicorn.workers.UvicornWorker"]
