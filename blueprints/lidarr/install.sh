#!/usr/local/bin/bash
# This file contains the install script for lidarr

#init jail
initblueprint "$1"

# Initialise defaults

# Check if dataset for completed download and it parent dataset exist, create if they do not.
createmount "$1" "${global_dataset_downloads}"
createmount "$1" "${global_dataset_downloads}"/complete /mnt/fetched

# Check if dataset for media library and the dataset for movies exist, create if they do not.
createmount "$1" "${global_dataset_media}"
createmount "$1" "${global_dataset_media}"/music /mnt/music


iocage exec "$1" "fetch https://github.com/lidarr/Lidarr/releases/download/v0.7.1.1381/Lidarr.master.0.7.1.1381.linux.tar.gz -o /usr/local/share"
iocage exec "$1" "tar -xzvf Lidarr.master.0.7.1.1381.linux.tar.gz -C /usr/local/share"
iocage exec "$1" "rm /usr/local/share/Lidarr.master.0.7.1.1381.linux.tar.gz"
iocage exec "$1" "pw user add lidarr -c lidarr -u 353 -d /nonexistent -s /usr/bin/nologin"
iocage exec "$1" chown -R lidarr:lidarr /usr/local/share/Lidarr /config
iocage exec "$1" mkdir /usr/local/etc/rc.d
cp "${SCRIPT_DIR}"/blueprints/lidarr/includes/lidarr.rc /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/rc.d/lidarr
iocage exec "$1" chmod u+x /usr/local/etc/rc.d/lidarr
iocage exec "$1" sysrc "lidarr_enable=YES"
iocage exec "$1" service lidarr start
