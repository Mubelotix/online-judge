# Inspired from https://docs.dmoj.ca/#/site/installation

FROM debian:bullseye-slim

# Update the package list and install necessary packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    build-essential \
    libmariadb-dev \
    gettext \
    && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Verify the Node.js version (should be 18.x)
RUN node -v

# Set the working directory
WORKDIR /app

# Clone git repository
RUN git clone https://github.com/DMOJ/online-judge /app
RUN git submodule update --init --recursive

# Install dependencies
RUN npm install -g sass postcss-cli postcss autoprefixer
RUN pip3 install -r requirements.txt
RUN pip3 install mysqlclient
RUN pip3 install lxml[html_clean] lxml_html_clean

# Add some configuration
RUN echo "STATIC_ROOT = '/app/static/'\n\
CACHES = {\n\
    'default': {\n\
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',\n\
    },\n\
}" >> /app/dmoj/local_settings.py

# Compile assets
RUN ./make_style.sh
RUN python3 manage.py collectstatic
RUN python3 manage.py compilemessages
RUN python3 manage.py compilejsi18n
RUN python3 manage.py createsuperuser

# Expose the necessary ports (e.g., for Django development server)
EXPOSE 8000

# Create an entrypoint script
RUN echo '#!/bin/sh' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'python3 manage.py migrate --noinput' >> /entrypoint.sh && \
    echo 'python3 manage.py createsuperuser --noinput' >> /entrypoint.sh && \
    echo 'python3 manage.py runserver 0.0.0.0:8000' >> /entrypoint.sh

RUN cat  /entrypoint.sh

# Make the entrypoint script executable
RUN chmod +x /entrypoint.sh

# Use the entrypoint script as the command
ENTRYPOINT ["/entrypoint.sh"]
