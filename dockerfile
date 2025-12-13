# 1. Use Python 3.10 (Best compatibility for Horilla)
FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DATABASE_URL="" \
    DEBUG=False \
    SECRET_KEY=changeme \
    ALLOWED_HOSTS=*

# 2. Install "Heavy Duty" system dependencies
# We added pango, ffi, and openjp2 which are often required for PDF/Report generation tools
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
       libpango-1.0-0 \
       libpangoft2-1.0-0 \
       libgdk-pixbuf2.0-0 \
       libffi-dev \
       shared-mime-info \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 3. Copy files
COPY . /app/

# 4. PRE-INSTALL FIX: Remove strict psycopg2 from requirements if present
# This prevents it from trying to compile the driver from source.
# We will install 'psycopg2-binary' manually in the next step.
RUN sed -i '/psycopg2/d' requirements.txt

# 5. Install Python dependencies
# We install wheel first to ensure we can build packages that need it
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt uvicorn[standard] psycopg2-binary gunicorn

# 6. Create .env file
RUN echo "DATABASE_URL=$DATABASE_URL" > .env && \
    echo "DEBUG=$DEBUG" >> .env && \
    echo "SECRET_KEY=$SECRET_KEY" >> .env && \
    echo "ALLOWED_HOSTS=$ALLOWED_HOSTS" >> .env

# 7. Create entrypoint script
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'python manage.py migrate' >> /entrypoint.sh && \
    echo 'python manage.py collectstatic --noinput' >> /entrypoint.sh && \
    echo 'exec "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# 8. User setup
RUN useradd --create-home --uid 1000 appuser && \
    mkdir -p staticfiles media && \
    chown -R appuser:appuser /app /entrypoint.sh

USER appuser

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]

CMD ["uvicorn", "horilla.asgi:application", "--host", "0.0.0.0", "--port", "8000"]
