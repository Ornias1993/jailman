#!/usr/local/bin/bash
# This file contains the update script for mariadb

#init jail
initblueprint "$1"

# Initialise defaults
cert_email="${cert_email:-placeholder@email.fake}"
DL_FLAGS=""
DNS_ENV=""

# Install includes fstab
iocage exec "${1}" mkdir -p /mnt/includes
iocage fstab -a "${1}" "${includes_dir}" /mnt/includes nullfs rw 0 0


iocage exec "${1}" service caddy stop
iocage exec "${1}" service php-fpm stop

fetch -o /tmp https://getcaddy.com
if ! iocage exec "${1}" bash -s personal "${DL_FLAGS}" < /tmp/getcaddy.com
then
	echo "Failed to download/install Caddy"
	exit 1
fi

# Copy and edit pre-written config files
echo "Copying Caddyfile for no SSL"
iocage exec "${1}" cp -f /mnt/includes/caddy /usr/local/etc/rc.d/
iocage exec "${1}" cp -f /mnt/includes/Caddyfile /usr/local/www/Caddyfile
iocage exec "${1}" sed -i '' "s/yourhostnamehere/${host_name}/" /usr/local/www/Caddyfile
iocage exec "${1}" sed -i '' "s/JAIL-IP/${ip4_addr%/*}/" /usr/local/www/Caddyfile

# Don't need /mnt/includes any more, so unmount it
iocage fstab -r "${1}" "${includes_dir}" /mnt/includes nullfs rw 0 0

iocage exec "${1}" service caddy start
iocage exec "${1}" service php-fpm start