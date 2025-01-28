FROM ghcr.io/camptocamp/docker-odoo-project:18.0-master-latest

LABEL org.opencontainers.image.authors="jaco.tech"

RUN mkdir -p /odoo/src/odoo
COPY ./odoo/src/odoo /odoo/src/odoo
COPY ./odoo/enterprise /odoo/enterprise
COPY ./odoo/addons /odoo/odoo/addons
COPY ./data /odoo/data
COPY ./songs /odoo/songs
# COPY ./setup.py /odoo/
COPY ./VERSION /odoo/
COPY ./BUILD_DATE /odoo/
# COPY ./migration.yml /odoo/

USER root

# You can define an ARG for the MaxMind license key
ARG MAXMIND_LICENSE_KEY

RUN mkdir -p /usr/share/GeoIP

# Use curl instead of wget:
    RUN cd /tmp \
    && curl -SL "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=${MAXMIND_LICENSE_KEY}&suffix=tar.gz" \
       -o GeoLite2-City.tar.gz \
    && tar --wildcards --strip=1 -vxzf GeoLite2-City.tar.gz -C /usr/share/GeoIP/ GeoLite2*/GeoLite2-City.mmdb \
    && rm GeoLite2-City.tar.gz

RUN cd /tmp \
    && curl -SL "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=${MAXMIND_LICENSE_KEY}&suffix=tar.gz" \
       -o GeoLite2-Country.tar.gz \
    && tar --wildcards --strip=1 -vxzf GeoLite2-Country.tar.gz -C /usr/share/GeoIP/ GeoLite2*/GeoLite2-Country.mmdb \
    && rm GeoLite2-Country.tar.gz