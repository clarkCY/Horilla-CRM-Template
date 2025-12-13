# Must be Python 3.10 for Horilla compatibility
FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install the heavy dependencies required for PDFs (WeasyPrint)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential libpq-dev libjpeg-dev zlib1g-dev curl netcat-openbsd git \
       libcairo2-dev pkg-config libpango-1.0-0 libpangoft2-1.0-0 libgdk-pixbuf2.0-0 libffi-dev shared-mime-info \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /app/

# Remove psycopg2 from requirements.txt so we can use the binary version
RUN sed -i '/psycopg2/d' requirements.txt

# Install dependencies
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt uvicorn[standard] psycopg2-binary gunicorn

# Setup script (Entrypoint)
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'python manage.py migrate' >> /entrypoint.sh && \
    echo 'python manage.py collectstatic --noinput' >> /entrypoint.sh && \
    echo 'exec "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

RUN useradd --create-home --uid 1000 appuser && \
    mkdir -p staticfiles media && \
    chown -R appuser:appuser /app /entrypoint.sh

USER appuser
EXPOSE 8000
ENTRYPOINT ["/entrypoint.sh"]
CMD ["uvicorn", "horilla.asgi:application", "--host", "0.0.0.0", "--port", "8000"]
