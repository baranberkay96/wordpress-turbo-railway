#!/usr/bin/env bash
# Idempotent WP-CLI bootstrap, run on every boot before Apache starts.
#  - waits for MariaDB (bounded)
#  - installs WordPress once with the generated admin account (closes the public install wizard)
#  - installs + activates the Redis Object Cache plugin and enables its drop-in
# Each step is bounded by a timeout; any failure is logged and the caller still starts Apache.
set -Eeuo pipefail

WP_ROOT=/var/www/html
CLI_TIMEOUT="${WP_BOOTSTRAP_STEP_TIMEOUT:-180}"
DB_WAIT_SECONDS="${WP_BOOTSTRAP_DB_WAIT:-120}"
REDIS_PLUGIN_VERSION="${REDIS_CACHE_PLUGIN_VERSION:-3.0.0}"

log() { echo "[wp-bootstrap] $*" >&2; }

mkdir -p "${WP_CLI_CACHE_DIR:-/tmp/wp-cli-cache}" /tmp/wp-cli-home
chown www-data:www-data "${WP_CLI_CACHE_DIR:-/tmp/wp-cli-cache}" /tmp/wp-cli-home

# Run WP-CLI as the web server user so files it creates are writable by Apache.
wp_cli() {
    timeout "${CLI_TIMEOUT}" runuser -u www-data -- env HOME=/tmp/wp-cli-home \
        wp --path="${WP_ROOT}" --skip-themes "$@"
}

# --- 1. Wait for the database (same driver WordPress uses) -----------------------------
db_ready() {
    php -r '
        $host = getenv("WORDPRESS_DB_HOST") ?: "localhost";
        $port = 3306;
        if (preg_match("/^(.*):(\d+)$/", $host, $m)) { $host = $m[1]; $port = (int) $m[2]; }
        mysqli_report(MYSQLI_REPORT_OFF);
        $db = @new mysqli($host, getenv("WORDPRESS_DB_USER"), getenv("WORDPRESS_DB_PASSWORD"),
                          getenv("WORDPRESS_DB_NAME"), $port);
        exit($db->connect_errno ? 1 : 0);
    ' >/dev/null 2>&1
}

waited=0
until db_ready; do
    if [ "${waited}" -ge "${DB_WAIT_SECONDS}" ]; then
        log "database not reachable after ${DB_WAIT_SECONDS}s; skipping bootstrap for this boot"
        exit 1
    fi
    sleep 3
    waited=$((waited + 3))
done
log "database reachable"

# --- 2. Install WordPress once -----------------------------------------------------------
if wp_cli core is-installed --skip-plugins >/dev/null 2>&1; then
    log "WordPress already installed"
    # After an image upgrade, bring the database schema up to the new core version
    # (no-op when it is already current).
    wp_cli core update-db --skip-plugins || log "core update-db failed; run it from wp-admin"
elif [ -n "${WP_ADMIN_EMAIL:-}" ] && [ -n "${WP_ADMIN_PASSWORD:-}" ] && [ -n "${WP_PUBLIC_URL:-}" ]; then
    log "installing WordPress for ${WP_PUBLIC_URL} (admin user: ${WP_ADMIN_USER:-siteadmin})"
    printf '%s\n' "${WP_ADMIN_PASSWORD}" | wp_cli core install --skip-plugins \
        --url="${WP_PUBLIC_URL}" \
        --title="${WP_SITE_TITLE:-My WordPress Site}" \
        --admin_user="${WP_ADMIN_USER:-siteadmin}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --prompt=admin_password \
        --skip-email
    wp_cli rewrite structure '/%postname%/' --skip-plugins || log "could not set pretty permalinks"
    if [ -n "${WP_LOCALE:-}" ] && [ "${WP_LOCALE}" != "en_US" ]; then
        wp_cli language core install "${WP_LOCALE}" --activate --skip-plugins \
            || log "could not install language ${WP_LOCALE}"
    fi
else
    log "WP_ADMIN_EMAIL, WP_ADMIN_PASSWORD or WP_PUBLIC_URL missing: not auto-installing."
    log "Finish setup in the browser at ${WP_PUBLIC_URL:-<your domain>}/wp-admin/install.php"
    exit 0
fi

# --- 3. Redis Object Cache plugin ---------------------------------------------------------
if [ "${WP_REDIS_AUTOENABLE:-true}" != "true" ]; then
    log "WP_REDIS_AUTOENABLE=false: leaving the object cache configuration untouched"
    exit 0
fi
if [ -z "${WP_REDIS_HOST:-}" ]; then
    log "WP_REDIS_HOST not set: skipping Redis Object Cache"
    exit 0
fi

if ! wp_cli plugin is-installed redis-cache --skip-plugins; then
    log "installing redis-cache ${REDIS_PLUGIN_VERSION} from wordpress.org"
    wp_cli plugin install redis-cache --version="${REDIS_PLUGIN_VERSION}" --skip-plugins
fi
if ! wp_cli plugin is-active redis-cache --skip-plugins; then
    wp_cli plugin activate redis-cache
fi
# "enable" is idempotent: it reports "already enabled" when our drop-in is present and refuses
# to overwrite a drop-in that belongs to another caching plugin.
wp_cli redis enable
log "done"
