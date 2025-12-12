FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DATABASE_URL="" \
    DEBUG=False \
    SECRET_KEY=changeme \
    ALLOWED_HOSTS=*

# 1. Install system dependencies (We added git and netcat)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       libpq-dev \
       libjpeg-dev \
       zlib1g-dev \
       curl \
       netcat-openbsd \
       git \
    && rm -rf /var/lib/apt/lists/*

# 2. Create the working directory
WORKDIR /app

# 3. FIX: Copy the specific subfolder contents to the main app folder
# This grabs what is inside 'horilla-crm' and puts it in the main '/app' spot
COPY horilla-crm/ /app/

# 4. Install Python dependencies
# Now requirements.txt is safely in /app/ because of step 3
RUN pip install --no-cache-dir -r requirements.txt uvicorn[standard] psycopg2-binary gunicorn

# 5. Create the .env file dynamically
# (We create this manually to ensure Railway variables work with Uvicorn)
RUN echo "DATABASE_URL=$DATABASE_URL" > .env && \
    echo "DEBUG=$DEBUG" >> .env && \
    echo "SECRET_KEY=$SECRET_KEY" >> .env && \
    echo "ALLOWED_HOSTS=$ALLOWED_HOSTS" >> .env

# 6. Create a safe entrypoint script
# We write this manually because we can't be sure the 'docker/' folder exists in your copy
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'python manage.py migrate' >> /entrypoint.sh && \
    echo 'python manage.py collectstatic --noinput' >> /entrypoint.sh && \
    echo 'exec "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# 7. Create non-root user for security
RUN useradd --create-home --uid 1000 appuser && \
    mkdir -p staticfiles media && \
    chown -R appuser:appuser /app /entrypoint.sh

USER appuser

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]

# 8. Start with Uvicorn (as suggested by the repo)
CMD ["uvicorn", "horilla.asgi:application", "--host", "0.0.0.0", "--port", "8000"]