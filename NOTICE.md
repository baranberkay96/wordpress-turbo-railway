# Notice

## Upstream software

| Component | License | Distribution used |
|---|---|---|
| WordPress | GPL-2.0-or-later | Official Docker image `wordpress` (Docker Official Images, built from docker-library/wordpress) |
| PHP / Apache httpd | PHP License v3.01 / Apache-2.0 | Included in the `wordpress` image (`php:8.3-apache`) |
| WP-CLI | MIT | Release phar from github.com/wp-cli/wp-cli, verified by SHA-512 |
| phpredis | PHP License v3.01 | PECL package `redis`, compiled at image build |
| Redis Object Cache (redis-cache) | GPL-3.0-or-later | Downloaded from wordpress.org by WP-CLI at first boot (not redistributed in this repository) |
| MariaDB Server | GPL-2.0 | Official Docker image `mariadb` |
| Redis | RSALv2 / SSPLv1 / AGPLv3 (Redis 8 tri-license) | Official Docker image `redis` (Railway base definition) |
| curl | curl license (MIT-style) | `curlimages/curl` image |

## Verified against

| What | Source | Version / ref | Checked |
|---|---|---|---|
| Image build, entrypoint and wp-config behaviour | https://github.com/docker-library/wordpress/tree/master/latest/php8.3/apache (`Dockerfile`, `docker-entrypoint.sh`, `wp-config-docker.php`) | WordPress 7.1.3 (`version='7.1.3'` in Dockerfile) | 2026-10-10 |
| Current WordPress release | https://api.wordpress.org/core/version-check/1.7/ | 7.1.3 | 2026-10-10 |
| Image tags / `latest` mapping | Docker Hub `library/wordpress` (`latest` = `7.1.3-php8.3-apache` digest) | — | 2026-10-10 |
| MariaDB LTS tag | Docker Hub `library/mariadb` (`lts` = `12.3.3` digest) | 12.3.3 | 2026-10-10 |
| WP-CLI release + checksum | https://github.com/wp-cli/wp-cli/releases/tag/v2.12.0 (`wp-cli-2.12.0.phar.sha512`) | v2.12.0 | 2026-10-10 |
| phpredis | https://pecl.php.net/package/redis (stable 6.3.0) | 6.3.0 | 2026-10-10 |
| Redis Object Cache constants and WP-CLI commands | https://github.com/rhubarbgroup/redis-cache (`includes/object-cache.php`, `includes/cli/class-commands.php`) | 3.0.0 | 2026-10-10 |
| Railway cron rules (5-minute minimum, UTC, process must exit) | https://docs.railway.com/reference/cron-jobs | — | 2026-10-10 |
| MPM error reports | Railway Central Station threads on "More than one MPM loaded" (community, no official root cause) | — | 2026-10-10 |

## Adapted code

None. All files in `services/wordpress/` (Dockerfile, entrypoint, bootstrap script, PHP/Apache configuration, must-use plugin, health check) were written for this template. They call the official image's own `docker-entrypoint.sh` / `docker-ensure-installed.sh` and patch one line into the image's `wp-config-docker.php` at build time (a `require_once` of the template config); no upstream file is copied into this repository.

## Reference only (not copied)

- Railway market templates `wordpress-mpm-patched`, `EP4wIt`, `yG1Jw8` (serializedConfig and readme): read to compare service layout and the MPM workaround. No repository, files or README text copied. None of them has a source repository with a license.

## Trademarks

WordPress is a trademark of the WordPress Foundation. MariaDB is a trademark of MariaDB plc. Redis is a trademark of Redis Ltd. This is a community template and is not affiliated with or endorsed by these organizations.
