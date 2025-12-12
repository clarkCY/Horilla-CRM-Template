FROM python:3.10-slim-bullseye

ENV PYTHONUNBUFFERED=1
ENV DATABASE_URL=""
ENV DEBUG=False
ENV SECRET_KEY=changeme
ENV ALLOWED_HOSTS=*
ENV CSRF_TRUSTED_ORIGINS=
ENV TIME_ZONE=UTC

# 1. Install system libraries
RUN apt-get update && apt-get install -y \
    libcairo2-dev \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Prepare the main container directory
WORKDIR /app

# 3. Copy EVERYTHING from your repo into the container
COPY . /app/

# --- THE FIX IS HERE ---
# Since your code is inside a subfolder named "horilla-crm",
# we must change our working directory to be inside that folder.
WORKDIR /app/horilla-crm
# -----------------------

# 4. Install dependencies (Now it will find the file!)
RUN pip install -r requirements.txt && pip install gunicorn

# 5. Create the .env file (It will now be created inside the subfolder)
RUN rm -f .env.example && \
    echo "DATABASE_URL=$DATABASE_URL" > .env && \
    echo "DEBUG=$DEBUG" >> .env && \
    echo "SECRET_KEY=$SECRET_KEY" >> .env && \
    echo "ALLOWED_HOSTS=$ALLOWED_HOSTS" >> .env && \
    echo "CSRF_TRUSTED_ORIGINS=$CSRF_TRUSTED_ORIGINS" >> .env && \
    echo "TIME_ZONE=$TIME_ZONE" >> .env

# 6. Create the entrypoint script
# We make sure this script runs from the current directory
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'python manage.py migrate' >> /entrypoint.sh && \
    echo 'python manage.py collectstatic --noinput' >> /entrypoint.sh && \
    echo 'exec "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]

# 7. Start Gunicorn
CMD ["gunicorn", "horilla_crm.wsgi:application", "--bind", "0.0.0.0:8000"]