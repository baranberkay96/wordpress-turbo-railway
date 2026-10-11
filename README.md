# Deploy and Host WordPress with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/wordpress-7-turbo-redis-cache-mariadb)

Run a production-ready WordPress site on Railway with MariaDB, a Redis object cache, tuned PHP and a real cron schedule. The site installs itself on first boot with a generated admin password, keeps plugins, themes and uploads on a persistent volume, and avoids the Apache "More than one MPM loaded" crash. Community template.

## About Hosting WordPress

WordPress is a PHP application that needs a MySQL-compatible database, a web server and somewhere durable to keep uploads, plugins and themes. A default container install works, but it leaves performance and reliability on the table: every page load rebuilds options from the database, scheduled tasks only run when someone visits, and PHP limits are too small for real media libraries. This template packages the official WordPress image with Apache prefork, PHP 8.3 and OPcache tuning, the native `phpredis` extension and the Redis Object Cache plugin, a MariaDB LTS database on Railway's private network, and a Railway cron service that triggers `wp-cron.php` every five minutes.

## Common Use Cases

- Company websites and landing pages that need a familiar editor for non-technical teams
- Blogs and content hubs with scheduled publishing
- WooCommerce or membership sites that benefit from a persistent object cache
- Agency staging/production environments with pinned, reproducible versions

## Dependencies for WordPress Hosting

- WordPress 7.1 (official `wordpress` Docker image, PHP 8.3, Apache)
- MariaDB 12.3 LTS (database)
- Redis 8.2 (persistent object cache)
- A Railway cron service (curl) for WP-Cron

### Deployment Dependencies

- WordPress Docker image: https://hub.docker.com/_/wordpress
- WordPress hosting requirements: https://wordpress.org/about/requirements/
- WP-CLI: https://wp-cli.org/
- Redis Object Cache plugin: https://wordpress.org/plugins/redis-cache/
- MariaDB Docker image: https://hub.docker.com/_/mariadb
- Railway cron jobs: https://docs.railway.com/reference/cron-jobs

### Implementation Details

| Service | Image | Purpose |
|---|---|---|
| WordPress | `wordpress:7.1.3-php8.3-apache` + template layer | Web server, PHP, WP-CLI, health endpoint `/healthz`, volume on `/var/www/html/wp-content` |
| MariaDB | `mariadb:12.3.3` | Database on the private network, volume on `/var/lib/mysql` |
| Redis | `redis:8.2` | Object cache backend, password protected |
| WP Cron | `curlimages/curl:8.22.0` | Calls `wp-cron.php` every 5 minutes over the private network |

**First login**

1. When deploying, enter `WP_ADMIN_EMAIL` (the only required input).
2. Wait for the WordPress service to turn healthy (first boot installs WordPress and the Redis Object Cache plugin).
3. Open the service's public domain and go to `/wp-admin`. Log in with `WP_ADMIN_USER` (default `siteadmin`) and the generated `WP_ADMIN_PASSWORD` from the WordPress service's Variables tab.
4. Change the password in Users → Profile. Check Settings → Redis shows "Connected".

**Custom domain**

Add the domain to the WordPress service, set `WP_PUBLIC_URL` to `https://your-domain`, redeploy, then rewrite stored links once from a shell on the service: `wp search-replace 'https://old-domain' 'https://your-domain' --all-tables --allow-root`.

**Scaling**

The WordPress service owns a volume, so it scales vertically: raise the service's memory and `APACHE_MAX_REQUEST_WORKERS` together (about 60 MB per worker). PHP limits (`PHP_MEMORY_LIMIT`, `PHP_UPLOAD_MAX_FILESIZE`, `PHP_POST_MAX_SIZE`, `PHP_MAX_EXECUTION_TIME`) and the MariaDB buffer pool (start command) are adjustable. The cron interval is the WP Cron service's schedule (minimum 5 minutes).

**Pinning and upgrades**

Core WordPress files come from the container image and are refreshed on every deploy; only `wp-content` is persistent. To upgrade WordPress, change `WORDPRESS_IMAGE_TAG` in `services/wordpress/Dockerfile` (for example to a newer `7.x.y-php8.3-apache` tag) and redeploy; the boot script runs `wp core update-db` automatically. The one-click core update in the dashboard is hidden because it would be reverted on the next deploy. Plugins and themes update from the dashboard as usual. MariaDB minor upgrades are applied with `MARIADB_AUTO_UPGRADE`; take a backup (`wp db export --allow-root`) before changing major versions.

### Why Deploy WordPress on Railway?

Railway runs the web server, database, cache and cron schedule as separate services on one private network, with volumes, generated secrets and per-second usage billing. You get a WordPress stack that is fast and persistent from the first deploy, and you can resize, redeploy or roll back each part independently without managing a server.
