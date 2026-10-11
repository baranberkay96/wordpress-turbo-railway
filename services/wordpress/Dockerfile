# WordPress for Railway: official image + single Apache MPM, phpredis, WP-CLI,
# tuned PHP/OPcache/Apache, health endpoint and a boot-time bootstrap.
#
# Upgrade WordPress by changing WORDPRESS_IMAGE_TAG (core files come from the image;
# only wp-content lives on the volume).
ARG WORDPRESS_IMAGE_TAG=7.1.3-php8.3-apache
FROM wordpress:${WORDPRESS_IMAGE_TAG}

ARG WP_CLI_VERSION=2.12.0
ARG WP_CLI_SHA512=be928f6b8ca1e8dfb9d2f4b75a13aa4aee0896f8a9a0a1c45cd5d2c98605e6172e6d014dda2e27f88c98befc16c040cbb2bd1bfa121510ea5cdf5f6a30fe8832
ARG PHPREDIS_VERSION=6.3.0

# 1) Exactly one Apache MPM. Railway deployments of the stock image have failed with
#    "AH00534: More than one MPM loaded"; remove every MPM link and enable prefork only
#    (mod_php requires prefork). The entrypoint repeats this check at runtime.
RUN set -eux; \
    rm -f /etc/apache2/mods-enabled/mpm_*.load /etc/apache2/mods-enabled/mpm_*.conf; \
    a2enmod mpm_prefork; \
    test "$(ls /etc/apache2/mods-enabled/ | grep -c '^mpm_.*\.load$')" = "1"

# 2) phpredis extension (fast native client for the Redis Object Cache plugin),
#    MariaDB client (for `wp db export/import`), WP-CLI with checksum verification.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends mariadb-client; \
    rm -rf /var/lib/apt/lists/*; \
    pecl install "redis-${PHPREDIS_VERSION}"; \
    docker-php-ext-enable redis; \
    rm -rf /tmp/pear; \
    php -m | grep -qx redis; \
    curl -fsSL -o /usr/local/bin/wp \
      "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar"; \
    echo "${WP_CLI_SHA512}  /usr/local/bin/wp" | sha512sum -c -; \
    chmod 0755 /usr/local/bin/wp; \
    wp --allow-root --version

# 3) Tuning defaults (override any of them with Railway service variables).
ENV PHP_MEMORY_LIMIT=256M \
    PHP_UPLOAD_MAX_FILESIZE=64M \
    PHP_POST_MAX_SIZE=64M \
    PHP_MAX_EXECUTION_TIME=120 \
    PHP_MAX_INPUT_VARS=3000 \
    PHP_OPCACHE_MEMORY=192 \
    APACHE_MAX_REQUEST_WORKERS=20 \
    APACHE_MAX_CONNECTIONS_PER_CHILD=1000 \
    WP_CLI_CACHE_DIR=/tmp/wp-cli-cache

COPY config/zz-railway-php.ini   /usr/local/etc/php/conf.d/zz-railway-php.ini
COPY config/railway-apache.conf  /etc/apache2/conf-available/railway.conf
COPY config/mpm_prefork.conf     /etc/apache2/mods-available/mpm_prefork.conf
COPY config/railway-config.php   /usr/local/share/railway/railway-config.php
COPY config/health.php           /usr/local/share/railway/health/health.php
COPY config/railway-platform.php /usr/local/share/railway/mu-plugins/railway-platform.php
COPY scripts/railway-entrypoint.sh scripts/wp-bootstrap.sh /usr/local/bin/

# 4) Load railway-config.php from the generated wp-config.php (after WORDPRESS_CONFIG_EXTRA,
#    so anything you put there wins), enable the Apache snippet, and validate the config.
RUN set -eux; \
    chmod 0755 /usr/local/bin/railway-entrypoint.sh /usr/local/bin/wp-bootstrap.sh; \
    sed -i "s#^/\* That's all, stop editing! Happy publishing. \*/#require_once '/usr/local/share/railway/railway-config.php';\n\n&#" \
      /usr/src/wordpress/wp-config-docker.php; \
    grep -q "railway-config.php" /usr/src/wordpress/wp-config-docker.php; \
    php -l /usr/src/wordpress/wp-config-docker.php; \
    php -l /usr/local/share/railway/railway-config.php; \
    php -l /usr/local/share/railway/mu-plugins/railway-platform.php; \
    a2enconf railway; \
    apache2ctl -t

EXPOSE 80
ENTRYPOINT ["railway-entrypoint.sh"]
CMD ["apache2-foreground"]
