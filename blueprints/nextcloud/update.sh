#!/usr/local/bin/bash
# This file contains the update script for nextcloud

initblueprint "$1"

echo "running nextcloud update"
iocage exec -f nextcloud su -m www -c "php /usr/local/www/nextcloud/updater/updater.phar  --no-interaction"
iocage exec nextcloud service caddy restart
