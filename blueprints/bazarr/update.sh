#!/usr/local/bin/bash
# This file contains the update script for bazarr

#init jail
initblueprint "$1"

# Initialise defaults

iocage exec "$1" service bazarr stop
iocage exec "$1" git -C /usr/local/share/bazarr pull
iocage exec "$1" "pip install -r /usr/local/share/bazarr/requirements.txt"
iocage exec "$1" chown -R bazarr:bazarr /usr/local/share/bazarr /config
cp "${SCRIPT_DIR}"/blueprints/bazarr/includes/bazarr.rc /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/rc.d/bazarr
iocage exec "$1" chmod u+x /usr/local/etc/rc.d/bazarr
iocage exec "$1" service bazarr restart