FROM ghcr.io/camptocamp/docker-odoo-project:18.0-master-latest

LABEL org.opencontainers.image.authors="jaco.tech"

USER odoo

RUN mkdir -p /odoo/src/odoo /odoo/custom-addons
# moving lower for better layer caching
# COPY ./odoo/src/odoo /odoo/src/odoo
# COPY ./odoo/addons /odoo/odoo/addons
# COPY ./odoo/enterprise /odoo/enterprise
COPY ./VERSION /odoo/
COPY ./BUILD_DATE /odoo/

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      parallel \
      openssh-client \
      curl \
      libsasl2-dev \
      libldap2-dev \
      libssl-dev \
      libmagic1 \
      libpq-dev \
      build-essential \
      python3-dev \
      libffi-dev \
      pkg-config \
      libcairo2-dev \
      libgirepository1.0-dev \
      python3-shapely && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# MaxMind license key should be passed as a build secret
# Usage: docker build --secret id=maxmind_key,src=maxmind_key.txt .

RUN mkdir -p /usr/share/GeoIP

# Use curl instead of wget:
RUN --mount=type=secret,id=maxmind_key \
    if [ -f /run/secrets/maxmind_key ]; then \
        cd /tmp \
        && curl -SL "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=$(cat /run/secrets/maxmind_key)&suffix=tar.gz" \
           -o GeoLite2-City.tar.gz \
        && tar --wildcards --strip=1 -vxzf GeoLite2-City.tar.gz -C /usr/share/GeoIP/ GeoLite2*/GeoLite2-City.mmdb \
        && rm GeoLite2-City.tar.gz; \
    else \
        echo "Warning: MaxMind license key not provided, skipping GeoLite2-City database download"; \
    fi

RUN --mount=type=secret,id=maxmind_key \
    if [ -f /run/secrets/maxmind_key ]; then \
        cd /tmp \
        && curl -SL "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=$(cat /run/secrets/maxmind_key)&suffix=tar.gz" \
           -o GeoLite2-Country.tar.gz \
        && tar --wildcards --strip=1 -vxzf GeoLite2-Country.tar.gz -C /usr/share/GeoIP/ GeoLite2*/GeoLite2-Country.mmdb \
        && rm GeoLite2-Country.tar.gz; \
    else \
        echo "Warning: MaxMind license key not provided, skipping GeoLite2-Country database download"; \
    fi


RUN rm -rf /odoo/src/odoo/odoo.egg-info

COPY ./requirements.txt /odoo/
COPY ./odoo/src /odoo/src
COPY ./odoo/addons /odoo/odoo/addons
COPY ./odoo/enterprise /odoo/enterprise
COPY ./odoo/design-themes /odoo/design-themes

USER odoo
WORKDIR /odoo
# run in a virtualenv
# RUN /odoo/.venv/bin/pip install -r /odoo/src/odoo/requirements.txt
# RUN /odoo/.venv/bin/pip install --config-settings editable_mode=compat -e /odoo/src/odoo
RUN /odoo/.venv/bin/pip install --user -r requirements.txt 
RUN /odoo/.venv/bin/pip install -r /odoo/src/requirements.txt
RUN /odoo/.venv/bin/pip install -e /odoo/src


ENV ADDONS_PATH=/odoo/custom-addons,/odoo/odoo/addons,/odoo/src/addons,/odoo/src/odoo/addons,/odoo/enterprise,/odoo/design-themes