<?php
/**
 * Railway template defaults, required from wp-config.php after WORDPRESS_CONFIG_EXTRA.
 *
 * Every constant is only defined when it is not already defined, so values set in
 * WORDPRESS_CONFIG_EXTRA always win. Values are read from environment variables.
 */

declare(strict_types=1);

if (!function_exists('railway_env')) {
    function railway_env(string $name, ?string $default = null): ?string
    {
        $value = getenv($name);
        return ($value === false || $value === '') ? $default : $value;
    }
}

if (!function_exists('railway_env_bool')) {
    function railway_env_bool(string $name, bool $default): bool
    {
        $value = railway_env($name);
        return $value === null ? $default : filter_var($value, FILTER_VALIDATE_BOOLEAN);
    }
}

if (!function_exists('railway_define')) {
    function railway_define(string $name, $value): void
    {
        if (!defined($name)) {
            define($name, $value);
        }
    }
}

// Public URL (Railway domain or your custom domain).
$railwayPublicUrl = railway_env('WP_PUBLIC_URL');
if ($railwayPublicUrl !== null) {
    railway_define('WP_HOME', rtrim($railwayPublicUrl, '/'));
    railway_define('WP_SITEURL', rtrim($railwayPublicUrl, '/'));
}
railway_define('FORCE_SSL_ADMIN', railway_env_bool('WP_FORCE_SSL_ADMIN', true));

// Real cron: page loads no longer trigger WP-Cron; the "WP Cron" Railway service calls
// wp-cron.php over the private network on a fixed schedule instead.
railway_define('DISABLE_WP_CRON', railway_env_bool('WP_DISABLE_PAGELOAD_CRON', true));

// Memory available to WordPress (front end / admin). PHP's own limit is PHP_MEMORY_LIMIT.
railway_define('WP_MEMORY_LIMIT', railway_env('WP_MEMORY_LIMIT', '256M'));
railway_define('WP_MAX_MEMORY_LIMIT', railway_env('WP_MAX_MEMORY_LIMIT', '512M'));

// Files: write directly as the web server user; hide the in-dashboard code editor.
railway_define('FS_METHOD', 'direct');
railway_define('DISALLOW_FILE_EDIT', railway_env_bool('WP_DISALLOW_FILE_EDIT', true));

// Core files come from the container image, so core updates are done by changing the
// image tag. Plugin and theme updates (stored in wp-content on the volume) still work.
railway_define('WP_AUTO_UPDATE_CORE', false);

// Redis Object Cache plugin (https://wordpress.org/plugins/redis-cache/).
$railwayRedisHost = railway_env('WP_REDIS_HOST');
if ($railwayRedisHost !== null) {
    railway_define('WP_REDIS_CLIENT', 'phpredis');
    railway_define('WP_REDIS_HOST', $railwayRedisHost);
    railway_define('WP_REDIS_PORT', (int) railway_env('WP_REDIS_PORT', '6379'));
    railway_define('WP_REDIS_DATABASE', (int) railway_env('WP_REDIS_DATABASE', '0'));
    railway_define('WP_REDIS_TIMEOUT', 1);
    railway_define('WP_REDIS_READ_TIMEOUT', 1);
    railway_define('WP_REDIS_MAXTTL', (int) railway_env('WP_REDIS_MAXTTL', '604800'));
    $railwayRedisPassword = railway_env('WP_REDIS_PASSWORD');
    if ($railwayRedisPassword !== null) {
        railway_define('WP_REDIS_PASSWORD', $railwayRedisPassword);
    }
    $railwayRedisUser = railway_env('WP_REDIS_USERNAME');
    if ($railwayRedisUser !== null) {
        railway_define('WP_REDIS_USERNAME', $railwayRedisUser);
    }
}

unset($railwayPublicUrl, $railwayRedisHost, $railwayRedisPassword, $railwayRedisUser);
