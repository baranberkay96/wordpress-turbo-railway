#!/usr/bin/env bash
# Entrypoint for the WordPress service on Railway.
#  1. Guarantees exactly one Apache MPM (fixes "AH00534: More than one MPM loaded").
#  2. Prepares the wp-content volume (ownership, lost+found).
#  3. Copies core files and generates wp-config.php using the official image logic.
#  4. Installs the template's must-use plugin.
#  5. Runs the WP-CLI bootstrap (install, Redis Object Cache) - failures never block startup.
#  6. Hands over to the official entrypoint / Apache.
set -Eeuo pipefail

WP_ROOT=/var/www/html
log() { echo "[railway-entrypoint] $*" >&2; }

# 1. Single MPM guard (also enforced at build time).
mpm_count="$(find /etc/apache2/mods-enabled -maxdepth 1 -name 'mpm_*.load' | wc -l)"
if [ "$mpm_count" != "1" ] || [ ! -e /etc/apache2/mods-enabled/mpm_prefork.load ]; then
    log "found ${mpm_count} enabled MPM modules; enabling mpm_prefork only"
    rm -f /etc/apache2/mods-enabled/mpm_*.load /etc/apache2/mods-enabled/mpm_*.conf
    a2enmod -q mpm_prefork
fi

# 2. Volume preparation. Railway mounts the volume owned by root.
mkdir -p "${WP_ROOT}/wp-content"
rmdir --ignore-fail-on-non-empty "${WP_ROOT}/wp-content/lost+found" 2>/dev/null || true
if [ "$(stat -c '%U' "${WP_ROOT}/wp-content")" != "www-data" ]; then
    log "setting ownership of ${WP_ROOT}/wp-content to www-data (first boot on this volume)"
    chown -R www-data:www-data "${WP_ROOT}/wp-content"
fi

# 3. Copy core from the image and render wp-config.php from WORDPRESS_* variables.
#    The official script does this and then runs its arguments ("true" = do nothing else).
cd "${WP_ROOT}"
docker-ensure-installed.sh true

# 4. Must-use plugin shipped with the template (always refreshed from the image).
install -d -o www-data -g www-data "${WP_ROOT}/wp-content/mu-plugins"
install -o www-data -g www-data -m 0644 \
    /usr/local/share/railway/mu-plugins/railway-platform.php \
    "${WP_ROOT}/wp-content/mu-plugins/railway-platform.php"

# 5. WP-CLI bootstrap.
if [ "${WP_BOOTSTRAP:-true}" = "true" ]; then
    wp-bootstrap.sh || log "bootstrap reported a problem (see above); starting Apache anyway"
else
    log "WP_BOOTSTRAP=false: skipping WP-CLI bootstrap"
fi

# 6. Official entrypoint (no-op copy check) then Apache in the foreground.
exec docker-entrypoint.sh "$@"
