#!/usr/local/bin/bash
# This file contains the install script for lidarr

#init jail
initblueprint "$1"

# Initialise defaults
FILE_NAME=$(curl -s https://api.github.com/repos/lidarr/Lidarr/releases | jq -r '[[.[] | select(.draft != true) | select(.prerelease == true)][0] | .assets | .[] | select(.name | endswith(".linux.tar.gz")) | .name][0]')
DOWNLOAD=$(curl -s https://api.github.com/repos/lidarr/Lidarr/releases | jq -r '[[.[] | select(.draft != true) | select(.prerelease == true)][0] | .assets | .[] | select(.name | endswith(".linux.tar.gz")) | .browser_download_url][0]')

# Check if dataset for completed download and it parent dataset exist, create if they do not.
createmount "$1" "${global_dataset_downloads}"
createmount "$1" "${global_dataset_downloads}"/complete /mnt/fetched

# Check if dataset for media library and the dataset for movies exist, create if they do not.
createmount "$1" "${global_dataset_media}"
createmount "$1" "${global_dataset_media}"/music /mnt/music
  
iocage exec "${1}" fetch -o /usr/local/share "${DOWNLOAD}"
iocage exec "$1" "tar -xzvf /usr/local/share/${FILE_NAME} -C /usr/local/share"
iocage exec "$1" rm /usr/local/share/"${FILE_NAME}"
iocage exec "$1" "pw user add lidarr -c lidarr -u 353 -d /nonexistent -s /usr/bin/nologin"
iocage exec "$1" chown -R lidarr:lidarr /usr/local/share/Lidarr /config
iocage exec "$1" mkdir /usr/local/etc/rc.d
cp "${includes_dir}"/lidarr.rc /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/rc.d/lidarr
iocage exec "$1" chmod u+x /usr/local/etc/rc.d/lidarr
iocage exec "$1" sysrc "lidarr_enable=YES"
iocage exec "$1" service lidarr start

exitblueprint "$1"
