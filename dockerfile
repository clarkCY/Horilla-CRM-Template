FROM python:3.10-slim-bullseye

ENV PYTHONUNBUFFERED=1
ENV DATABASE_URL=""
ENV DEBUG=False
ENV SECRET_KEY=changeme
ENV ALLOWED_HOSTS=*
ENV CSRF_TRUSTED_ORIGINS=
ENV TIME_ZONE=UTC

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcairo2-dev \
    gcc \
    git \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone the CRM specific repository
RUN git clone https://github.com/horilla-opensource/horilla-crm.git

# The directory name for CRM is 'horilla-crm', not 'horilla'
WORKDIR /horilla-crm

# Checkout master (default, but good to be explicit)
RUN git checkout master

# CRM uses .env.example, not .env.dist
RUN rm -f .env.example

# Create the .env file from environment variables
RUN echo "DATABASE_URL=$DATABASE_URL" > .env
RUN echo "DEBUG=$DEBUG" >> .env
RUN echo "SECRET_KEY=$SECRET_KEY" >> .env
RUN echo "ALLOWED_HOSTS=$ALLOWED_HOSTS" >> .env
RUN echo "CSRF_TRUSTED_ORIGINS=$CSRF_TRUSTED_ORIGINS" >> .env
RUN echo "TIME_ZONE=$TIME_ZONE" >> .env

# Install Python dependencies
RUN pip install -r requirements.txt

# Create a simple entrypoint script dynamically
# (Horilla CRM doesn't always include a dedicated entrypoint.sh in the root)
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'python manage.py migrate' >> /entrypoint.sh && \
    echo 'python manage.py collectstatic --noinput' >> /entrypoint.sh && \
    echo 'exec "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]

# Use Gunicorn for better production performance than runserver
CMD ["gunicorn", "horilla_crm.wsgi:application", "--bind", "0.0.0.0:8000"]