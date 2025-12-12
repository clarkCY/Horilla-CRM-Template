FROM python:3.10-slim-bullseye

ENV PYTHONUNBUFFERED=1
ENV DATABASE_URL=""
ENV DEBUG=False
ENV SECRET_KEY=changeme
ENV ALLOWED_HOSTS=*
ENV CSRF_TRUSTED_ORIGINS=
ENV TIME_ZONE=UTC

# 1. Install system libraries (including database clients)
RUN apt-get update && apt-get install -y \
    libcairo2-dev \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Set the working directory
WORKDIR /app

# 3. Copy only requirements first (to cache dependencies and make builds faster)
COPY requirements.txt /app/

# 4. Install Python dependencies + Gunicorn
RUN pip install -r requirements.txt && pip install gunicorn

# 5. COPY YOUR CODE (This replaces the git clone)
# This takes whatever is in your 'clarkCY' repo and puts it in the container
COPY . /app/

# 6. Create the .env file from Railway variables
RUN rm -f .env.example && \
    echo "DATABASE_URL=$DATABASE_URL" > .env && \
    echo "DEBUG=$DEBUG" >> .env && \
    echo "SECRET_KEY=$SECRET_KEY" >> .env && \
    echo "ALLOWED_HOSTS=$ALLOWED_HOSTS" >> .env && \
    echo "CSRF_TRUSTED_ORIGINS=$CSRF_TRUSTED_ORIGINS" >> .env && \
    echo "TIME_ZONE=$TIME_ZONE" >> .env

# 7. Create the entrypoint script
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'python manage.py migrate' >> /entrypoint.sh && \
    echo 'python manage.py collectstatic --noinput' >> /entrypoint.sh && \
    echo 'exec "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]

# 8. Start the app
CMD ["gunicorn", "horilla_crm.wsgi:application", "--bind", "0.0.0.0:8000"]