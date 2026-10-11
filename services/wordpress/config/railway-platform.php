<?php
/**
 * Plugin Name: Railway Platform Helpers
 * Description: Hides the one-click WordPress core update, because core files come from the container image and would be reverted on the next deploy. Plugin and theme updates are unaffected. Managed by the template; recopied on every boot.
 * Version: 1.0.0
 * License: GPL-2.0-or-later
 */

declare(strict_types=1);

defined('ABSPATH') || exit;

$railwayLockCore = getenv('WP_LOCK_CORE_UPDATES');
if ($railwayLockCore === false || $railwayLockCore === '' || filter_var($railwayLockCore, FILTER_VALIDATE_BOOLEAN)) {
    add_filter(
        'map_meta_cap',
        static function (array $caps, string $cap): array {
            return $cap === 'update_core' ? ['do_not_allow'] : $caps;
        },
        10,
        2
    );
}
unset($railwayLockCore);
