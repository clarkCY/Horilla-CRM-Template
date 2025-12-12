FROM python:3.10-slim-bullseye

ENV PYTHONUNBUFFERED=1
ENV DATABASE_URL=""
ENV DEBUG=False
ENV SECRET_KEY=changeme
ENV ALLOWED_HOSTS=*
ENV CSRF_TRUSTED_ORIGINS=
ENV TIME_ZONE=UTC

# Install system libraries
RUN apt-get update && apt-get install -y \
    libcairo2-dev \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# --- CHANGED SECTION ---
# Instead of copying just requirements first, we copy EVERYTHING.
# This prevents the "requirements.txt not found" error if the path is slightly off.
COPY . /app/
# -----------------------

# Now install dependencies
# (If this fails, it means your repo is actually empty!)
RUN pip install -r requirements.txt && pip install gunicorn

# Create config variables
RUN rm -f .env.example && \
    echo "DATABASE_URL=$DATABASE_URL" > .env && \
    echo "DEBUG=$DEBUG" >> .env && \
    echo "SECRET_KEY=$SECRET_KEY" >> .env && \
    echo "ALLOWED_HOSTS=$ALLOWED_HOSTS" >> .env && \
    echo "CSRF_TRUSTED_ORIGINS=$CSRF_TRUSTED_ORIGINS" >> .env && \
    echo "TIME_ZONE=$TIME_ZONE" >> .env

# Create entrypoint
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'python manage.py migrate' >> /entrypoint.sh && \
    echo 'python manage.py collectstatic --noinput' >> /entrypoint.sh && \
    echo 'exec "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]

CMD ["gunicorn", "horilla_crm.wsgi:application", "--bind", "0.0.0.0:8000"]