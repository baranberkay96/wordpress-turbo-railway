<?php
// Railway healthcheck: proves Apache + PHP are serving. Intentionally does not load WordPress.
header('Content-Type: text/plain');
header('Cache-Control: no-store');
echo "ok\n";
