# Inspired from https://docs.dmoj.ca/#/site/installation

FROM debian:bullseye-slim

# Update the package list and install necessary packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    python3 \
    python3-dev \
    python3-pip \
    build-essential \
    libmariadb-dev \
    gettext \
    supervisor \
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

# Clone doc
RUN git clone https://github.com/DMOJ/docs /doc

# Install dependencies
RUN npm install -g sass postcss-cli postcss autoprefixer
RUN pip3 install -r requirements.txt
RUN pip3 install mysqlclient
RUN pip3 install lxml[html_clean] lxml_html_clean
RUN pip3 install uwsgi
RUN pip3 install redis

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

# Create uwsgi.ini
RUN cp /doc/sample_files/uwsgi.ini /app/uwsgi.ini
RUN sed -i 's|chdir = <dmoj repo dir>|chdir = /app|g' /app/uwsgi.ini
RUN sed -i 's|pythonpath = <dmoj repo dir>|pythonpath = /usr/bin/python3|g' /app/uwsgi.ini
RUN sed -i 's|virtualenv = <virtualenv path>|#virtualenv = <virtualenv path>|g' /app/uwsgi.ini

# Copy supervisord configuration
RUN mv /doc/sample_files/site.conf /etc/supervisor/conf.d/site.conf
RUN mv /doc/sample_files/bridged.conf /etc/supervisor/conf.d/bridged.conf
RUN mv /doc/sample_files/celery.conf /etc/supervisor/conf.d/celery.conf
RUN sed -i 's|user=<user to run under>|#user=<user to run under>|g' /etc/supervisor/conf.d/*.conf
RUN sed -i 's|<path to virtualenv>/bin/python|/usr/bin/python3|g' /etc/supervisor/conf.d/*.conf
RUN sed -i 's|<path to virtualenv>|/usr/local|g' /etc/supervisor/conf.d/*.conf
RUN sed -i 's|<path to site>|/app|g' /etc/supervisor/conf.d/*.conf

# Remove biuld dependencies
RUN apt purge -y \
    git \
    python3-pip \
    build-essential \
    gettext \
    nodejs \
    && apt autoremove -y \
    && apt clean

# Expose the necessary ports (e.g., for Django development server)
EXPOSE 8000

# Create an entrypoint script
RUN echo '#!/bin/sh\n\
    set -e\n\
    python3 manage.py migrate --noinput\n\
    python3 manage.py createsuperuser --noinput || true\n\
    # Substitue whatever STATIC_ROOT is set to in your settings\n\
    sed -i "s|STATIC_ROOT|/app/static/|g" /etc/supervisor/conf.d/site.conf\n\
    supervisord -n' >> /entrypoint.sh

RUN cat  /entrypoint.sh

# Make the entrypoint script executable
RUN chmod +x /entrypoint.sh

# Use the entrypoint script as the command
ENTRYPOINT ["/entrypoint.sh"]
