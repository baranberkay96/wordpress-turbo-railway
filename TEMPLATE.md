# WordPress 7 Turbo (Redis Cache + MariaDB) — Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **WordPress 7 Turbo (Redis Cache + MariaDB)** (LISTINGS.md name + version label "7" = pinned major, WordPress markets plain numbers) |
| Description | Fast, persistent WordPress with object caching, tuned PHP and real cron. (72 chars, unchanged) |
| Category | CMS |
| Tags | wordpress, cms, php, mariadb, redis, blog, website |

The description is delivered as written: Redis object cache (phpredis + Redis Object Cache plugin), tuned PHP/OPcache/Apache, real cron via a Railway cron service, persistent wp-content volume.

## Base market template

- **Base: `wordpress-mpm-patched`** ("WordPress (MPM Patched)", 224 active projects, fastest growing). It is the only market template that addresses the Apache "AH00534: More than one MPM loaded" crash that has broken stock-image deployments on Railway. Kept: official `wordpress` image, MariaDB on the private network, `WORDPRESS_*` variables with generated keys/salts, `WORDPRESS_CONFIG_EXTRA` for URLs.
- `EP4wIt` ("WordPress", 2,559 active): same idea, MPM fix and PHP upload tweaks appended inside a long start command; unpinned `wordpress`/`mariadb` images; MariaDB's `MARIADB_HOST`/`MARIADB_URL` point at a TCP-proxy domain (WordPress itself uses the private host). Took the idea of raising upload limits, rejected the rest.
- `yG1Jw8` ("WordPress + MySQL"): unpinned images, `WORDPRESS_DB_HOST` built from a full `mysql://` URL plus the TCP-proxy port (malformed), public MySQL TCP proxy. Nothing taken.
- No `_upstream` repos exist for this app (all three market templates are image-only); nothing copied from any template's README.

## Pinned versions

| Service | Image / source | Tag | Release date | Checked |
|---|---|---|---|---|
| WordPress | `services/wordpress` → `FROM wordpress` | `7.1.3-php8.3-apache` (= `latest` digest on 2026-10-10) | image published 2026-10-08 | 2026-10-10 |
| ↳ WP-CLI | GitHub release phar, sha512-verified | `2.12.0` | 2025-05-07 (still latest) | 2026-10-10 |
| ↳ phpredis | PECL `redis` | `6.3.0` (stable) | 2025-11-06 | 2026-10-10 |
| ↳ Redis Object Cache plugin | wordpress.org `redis-cache`, installed by WP-CLI on first boot | `3.0.0` | 2026-09-18 | 2026-10-10 |
| MariaDB | `mariadb` | `12.3.3` (current `lts` tag) | 2026-10-02 (image build) | 2026-10-10 |
| Redis | `redis` (Railway base) | `8.2` | Railway base | 2026-10-10 |
| WP Cron | `curlimages/curl` | `8.22.0` | 2026-09-02 | 2026-10-10 |

## Architecture

```
              Internet (HTTPS, Railway edge)
                         │
                         ▼
               ┌───────────────────┐  /healthz (Apache+PHP, no DB)
               │ WordPress :80     │  volume: /var/www/html/wp-content
               │ Apache prefork +  │
               │ PHP 8.3 + OPcache │
               └──┬─────────────┬──┘
     mysqli :3306 │             │ phpredis :6379
                  ▼             ▼
          ┌──────────────┐ ┌──────────┐
          │ MariaDB 12.3 │ │ Redis 8.2│   (private network only, no TCP proxy)
          │ /var/lib/mysql│ │ /data   │
          └──────────────┘ └──────────┘
                  ▲
   WP Cron (cron "*/5 * * * *") ── HTTP GET http://wordpress.railway.internal/wp-cron.php
```

- Core WordPress files come from the image (refreshed on every deploy); only `wp-content` (plugins, themes, uploads, languages, drop-ins) is persistent. `wp-config.php` is regenerated from variables on every deploy.
- Boot sequence (`railway-entrypoint.sh`): enforce one MPM → fix volume ownership → official copy/config step → install must-use plugin → `wp-bootstrap.sh` (wait for DB, `wp core install` once or `wp core update-db` after upgrades, install/activate `redis-cache`, `wp redis enable`) → Apache. Bootstrap failures are logged and never block startup.

## Services

### WordPress
- Source: repo `baranberkay96/wordpress-turbo-railway`, root directory `/services/wordpress` (Dockerfile build).
- Start command: none (image `ENTRYPOINT railway-entrypoint.sh`, `CMD apache2-foreground`). Pre-deploy: none.
- Healthcheck: `/healthz`, timeout 300 s (covers DB wait + first-boot plugin install).
- Public domain: yes, target port 80. TCP proxy: none.
- Volume: `/var/www/html/wp-content`.
- Restart: ON_FAILURE, 10 retries. Replicas: 1 (has a volume; scale vertically).

| Variable | Value | Description |
|---|---|---|
| PORT | `80` | Port Apache listens on; the public domain targets it. |
| WP_PUBLIC_URL | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Canonical site URL (WP_HOME/WP_SITEURL). Change for a custom domain. |
| WORDPRESS_DB_HOST | `${{MariaDB.RAILWAY_PRIVATE_DOMAIN}}:3306` | MariaDB host:port on the private network. |
| WORDPRESS_DB_NAME | `${{MariaDB.MARIADB_DATABASE}}` | Database name. |
| WORDPRESS_DB_USER | `${{MariaDB.MARIADB_USER}}` | Database user. |
| WORDPRESS_DB_PASSWORD | `${{MariaDB.MARIADB_PASSWORD}}` | Database password. |
| WORDPRESS_TABLE_PREFIX | `wp_` | Table prefix; do not change after install. |
| WORDPRESS_AUTH_KEY … WORDPRESS_NONCE_SALT (8 vars) | `${{secret(64)}}` each | Keys and salts, generated once. |
| WORDPRESS_CONFIG_EXTRA | *(empty)* | Optional raw PHP for wp-config.php; overrides template defaults. |
| WP_ADMIN_EMAIL | *(required input)* | Email of the first administrator. |
| WP_ADMIN_USER | `siteadmin` | First administrator username. |
| WP_ADMIN_PASSWORD | `${{secret(24)}}` | First administrator password (initial install only). |
| WP_SITE_TITLE | `My WordPress Site` | Site title for the initial install. |
| WP_LOCALE | `en_US` | Language installed/activated on first install. |
| WP_REDIS_HOST | `${{Redis.REDISHOST}}` | Redis host (private). |
| WP_REDIS_PORT | `${{Redis.REDISPORT}}` | Redis port. |
| WP_REDIS_PASSWORD | `${{Redis.REDIS_PASSWORD}}` | Redis password. |
| WP_REDIS_PREFIX | `wp:` | Cache key prefix. |
| WP_REDIS_MAXTTL | `604800` | Max cache TTL (7 days) to bound Redis memory. |
| WP_REDIS_AUTOENABLE | `true` | Enforce plugin + drop-in on each boot; `false` to manage caching yourself. |
| REDIS_CACHE_PLUGIN_VERSION | `3.0.0` | Plugin version installed on first boot. |
| WP_DISABLE_PAGELOAD_CRON | `true` | `DISABLE_WP_CRON`; the WP Cron service runs cron instead. |
| WP_MEMORY_LIMIT / WP_MAX_MEMORY_LIMIT | `256M` / `512M` | WordPress front-end / admin memory. |
| WP_DISALLOW_FILE_EDIT | `true` | Hide the dashboard code editor. |
| WP_LOCK_CORE_UPDATES | `true` | Hide one-click core update (core comes from the image). |
| PHP_MEMORY_LIMIT | `256M` | PHP memory_limit. |
| PHP_UPLOAD_MAX_FILESIZE / PHP_POST_MAX_SIZE | `64M` / `64M` | Upload limits. |
| PHP_MAX_EXECUTION_TIME | `120` | Execution/input time (s). |
| PHP_OPCACHE_MEMORY | `192` | OPcache memory (MB). |
| APACHE_MAX_REQUEST_WORKERS | `20` | Max concurrent PHP workers (~60 MB each). |

Image-level defaults that are not exposed as variables (override by adding the variable): `PHP_MAX_INPUT_VARS=3000`, `APACHE_MAX_CONNECTIONS_PER_CHILD=1000`, `WP_BOOTSTRAP=true`, `WP_BOOTSTRAP_DB_WAIT=120`, `WP_BOOTSTRAP_STEP_TIMEOUT=180`, `WP_FORCE_SSL_ADMIN=true`, `WP_REDIS_DATABASE=0`.

### MariaDB
- Source: image `mariadb:12.3.3`.
- Start command: `docker-entrypoint.sh mariadbd --innodb-buffer-pool-size=256M --max-allowed-packet=64M --max-connections=100`.
- Healthcheck: n/a (TCP service). Public domain: no. TCP proxy: none (add one only if you need external access).
- Volume: `/var/lib/mysql`. Restart: ON_FAILURE, 10. Replicas: 1.

| Variable | Value | Description |
|---|---|---|
| MARIADB_DATABASE | `wordpress` | Database created on first start. |
| MARIADB_USER | `wordpress` | Application user. |
| MARIADB_PASSWORD | `${{secret(32, "a-zA-Z0-9")}}` | Application password (generated). |
| MARIADB_ROOT_PASSWORD | `${{secret(32, "a-zA-Z0-9")}}` | Root password (generated). |
| MARIADB_AUTO_UPGRADE | `1` | Run `mariadb-upgrade` after image version changes. |
| RAILWAY_DEPLOYMENT_DRAINING_SECONDS | `60` | Clean shutdown on redeploy. |
| MYSQLHOST / MYSQLPORT / MYSQLUSER / MYSQLPASSWORD / MYSQLDATABASE | private host, `3306`, app user/password/db | Conventional names used by Railway's Data panel and MySQL tooling. |
| MYSQL_URL | `mysql://…@${{RAILWAY_PRIVATE_DOMAIN}}:3306/…` | Private connection URL. |

### Redis
Copied verbatim from `_railway-base/redis.json`: image `redis:8.2`, password-protected, volume `/data`, `--save 60 1`. Variables `REDISHOST`, `REDISPORT`, `REDISUSER`, `REDIS_PASSWORD`, `REDISPASSWORD`, `REDIS_URL` (descriptions as in the base). No public domain, no TCP proxy.

### WP Cron
- Source: image `curlimages/curl:8.22.0`.
- Start command: `/bin/sh -c 'curl -fsS --max-time 290 --retry 3 --retry-delay 10 --retry-connrefused -o /dev/null -w "wp-cron.php HTTP %{http_code} in %{time_total}s\n" "$WP_CRON_URL"'`.
- Cron schedule: `*/5 * * * *` (Railway minimum interval is 5 minutes, UTC). Restart policy: NEVER. No domain, no volume.

| Variable | Value | Description |
|---|---|---|
| WP_CRON_URL | `http://${{WordPress.RAILWAY_PRIVATE_DOMAIN}}/wp-cron.php?doing_wp_cron` | wp-cron.php over the private network. |

## Improvements over market templates

1. **MPM crash fixed in the image**, not in a fragile start command: all `mpm_*` links removed and only `mpm_prefork` enabled at build time, asserted by a build check, and re-checked at container start.
2. **Pinned versions** (WordPress 7.1.3 / PHP 8.3, MariaDB 12.3.3 LTS, curl 8.22.0, WP-CLI 2.12.0 with sha512 check, phpredis 6.3.0) instead of `latest`/untagged.
3. **Redis object cache that actually works**: Redis service + native `phpredis` extension + Redis Object Cache plugin installed, activated and enabled by WP-CLI on boot; bounded TTL; graceful if Redis is down.
4. **Real cron**: `DISABLE_WP_CRON` plus a Railway cron service hitting `wp-cron.php` every 5 minutes over the private network — scheduled posts and plugin jobs run even with no visitors, and page loads no longer pay for cron.
5. **Tuned runtime**: PHP memory/upload/execution limits, bigger OPcache, realpath cache, prefork worker cap sized for a container (prevents OOM under load), `expose_php`/`ServerTokens` off, static asset expiry headers.
6. **No public install wizard**: WordPress is installed on first boot with a generated admin password, closing the window in which anyone hitting the URL first could claim the site.
7. **Database stays private**: no public TCP proxy on the database (`wordpress-mpm-patched` and `yG1Jw8` expose port 3306 publicly); `MYSQL*` variables are provided so Railway's Data panel can connect over the private network.
8. **Correct persistence model**: volume on `wp-content` only; core is immutable and upgraded by image tag; one-click core updates hidden (they would be reverted on redeploy); `MARIADB_AUTO_UPGRADE` for DB image bumps.
9. **Real healthcheck** (`/healthz`, Apache+PHP) instead of none.
10. **Hardening defaults**: `DISALLOW_FILE_EDIT`, `FORCE_SSL_ADMIN`, deny-list for `.sql/.bak/.log/.ini/.sh` files, HTTPS detection behind Railway's proxy (from the official config).

## Resource estimate

| Service | Idle RAM | Typical RAM | Typical vCPU | Volume |
|---|---|---|---|---|
| WordPress | 200 MB | 500 MB (peaks ~1.4 GB at 20 workers) | 0.25 | 1–5 GB (`wp-content`) |
| MariaDB | 180 MB | 350 MB | 0.10 | 0.5–2 GB |
| Redis | 10 MB | 50 MB | 0.02 | < 0.1 GB |
| WP Cron | ~0 (runs ~2 s every 5 min) | ~20 MB while running | ~0 | — |
| **Total** | **~0.4 GB, ~0.05 vCPU** | **~0.9 GB, ~0.37 vCPU** | | **~3 GB** |

Estimated cost at Railway prices (RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month):
- Idle / low-traffic site: 0.4 × $10 + 0.05 × $20 + 3 × $0.15 ≈ **$5–6 / month**.
- Typical small business site: 0.9 × $10 + 0.37 × $20 + 3 × $0.15 ≈ **$17 / month**.
- Busy site (20 PHP workers saturated, 1 vCPU): ≈ $35–45 / month.

Minimum plan: **Hobby**. Every service fits the Trial's 1 GB RAM per service, so a Trial deploy works for evaluation; a production site should run on Hobby (up to 48 GB RAM and 5 GB volume per service). Use Pro when `wp-content` (mostly uploads) will exceed 5 GB.

## Verification checklist

1. Deploy, enter `WP_ADMIN_EMAIL`. All four services build/start; WordPress deploy turns healthy (`GET https://<domain>/healthz` → `200 ok`).
2. WordPress logs show `[wp-bootstrap] installing WordPress …`, `installing redis-cache 3.0.0`, `Object cache enabled.` and no `AH00534` line.
3. Open `https://<domain>/wp-admin`, log in with `WP_ADMIN_USER` / `WP_ADMIN_PASSWORD` from the WordPress service variables; change the password.
4. Settings → Redis: status **Connected**, client **PhpRedis**. Tools → Site Health: no "page cache"/"persistent object cache" critical issues; HTTPS detected.
5. Media → upload an image > 10 MB (works up to 64 MB).
6. Cron: WP Cron service runs every 5 min with `wp-cron.php HTTP 200`. Schedule a post 10 min ahead; confirm it publishes. Tools → Site Health shows no "scheduled event has failed".
7. Persistence: redeploy WordPress → uploaded media, installed plugins/themes and the Redis drop-in remain; login still valid (keys/salts unchanged).
8. Restart MariaDB → site recovers without manual steps.
9. Confirm MariaDB and Redis have no public networking.

## Open questions

- The root cause of Railway's "More than one MPM loaded" error is not publicly confirmed (community threads only). The build-time + runtime guard covers every known variant, but it should be verified on a fresh Railway deployment.
- The Dockerfile has not been built in this workspace (no image pulls were made); first CI/Railway build should confirm the `pecl install redis` step and the `wp-config-docker.php` patch (both have build-time assertions that fail loudly).
- WP-CLI 2.12.0 (May 2025) is still the latest release; compatibility with WordPress 7.1 core commands (`core install`, `plugin install`, `language core install`) is expected but not verified here.
- Custom domain change requires updating `WP_PUBLIC_URL` and a one-off `wp search-replace 'https://old' 'https://new' --all-tables` (documented in README); not automated on purpose.
- Uploads are limited by the volume size of the plan (5 GB on Hobby). Offloading media to a Railway Bucket needs a third-party plugin and a public read path (buckets are private), so it is not part of this template.
- Whether Railway's Data panel recognises a MariaDB service from the `MYSQL*` variables alone is not verified.
- Railway's edge proxy IP ranges are not documented; Apache `mod_remoteip` trusts private ranges only (official image default), so the logged client IP may be the proxy IP.
