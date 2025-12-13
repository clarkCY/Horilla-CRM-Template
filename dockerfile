# 1. Downgrade to Python 3.10 (Recommended for Horilla)
FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DATABASE_URL="" \
    DEBUG=False \
    SECRET_KEY=changeme \
    ALLOWED_HOSTS=*

# 2. Install system dependencies (Added libcairo2-dev and pkg-config)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       libpq-dev \
       libjpeg-dev \
       zlib1g-dev \
       curl \
       netcat-openbsd \
       git \
       libcairo2-dev \
       pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 3. Copy files
COPY . /app/

# 4. Install Python dependencies
# Upgrade pip/setuptools first to avoid build errors with older packages
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt uvicorn[standard] psycopg2-binary gunicorn

# 5. Create .env file
RUN echo "DATABASE_URL=$DATABASE_URL" > .env && \
    echo "DEBUG=$DEBUG" >> .env && \
    echo "SECRET_KEY=$SECRET_KEY" >> .env && \
    echo "ALLOWED_HOSTS=$ALLOWED_HOSTS" >> .env

# 6. Create entrypoint script
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'python manage.py migrate' >> /entrypoint.sh && \
    echo 'python manage.py collectstatic --noinput' >> /entrypoint.sh && \
    echo 'exec "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# 7. User setup
RUN useradd --create-home --uid 1000 appuser && \
    mkdir -p staticfiles media && \
    chown -R appuser:appuser /app /entrypoint.sh

USER appuser

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]

CMD ["uvicorn", "horilla.asgi:application", "--host", "0.0.0.0", "--port", "8000"]
