#!/usr/local/bin/bash
# This file contains the install script for bazarr

#init jail
initblueprint "$1"

# Initialise defaults

# Check if dataset for media library and the dataset for movies exist, create if they do not.
createmount "$1" "${global_dataset_media}"
createmount "$1" "${global_dataset_media}"/movies /mnt/movies
createmount "$1" "${global_dataset_media}"/series /mnt/series

iocage exec "$1" "git clone https://github.com/morpheus65535/bazarr.git /usr/local/share/bazarr"
iocage exec "$1" "pw user add bazarr -c bazarr -u 399 -d /nonexistent -s /usr/bin/nologin"
iocage exec "$1" "pip install -r /usr/local/share/bazarr/requirements.txt"
iocage exec "$1" chown -R bazarr:bazarr /usr/local/share/bazarr /config
iocage exec "$1" mkdir /usr/local/etc/rc.d
cp "${SCRIPT_DIR}"/blueprints/bazarr/includes/bazarr.rc /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/rc.d/bazarr
iocage exec "$1" chmod u+x /usr/local/etc/rc.d/bazarr
iocage exec "$1" sysrc "bazarr_enable=YES"
iocage exec "$1" service bazarr start

exitblueprint "$1"
