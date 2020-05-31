#!/usr/local/bin/bash
# This file contains the update script for lidarr

#init jail
initblueprint "$1"

# Initialise defaults
FILE_NAME=$(curl -s https://api.github.com/repos/lidarr/Lidarr/releases | jq -r '[[.[] | select(.draft != true) | select(.prerelease == true)][0] | .assets | .[] | select(.name | endswith(".linux.tar.gz")) | .name][0]')
DOWNLOAD=$(curl -s https://api.github.com/repos/lidarr/Lidarr/releases | jq -r '[[.[] | select(.draft != true) | select(.prerelease == true)][0] | .assets | .[] | select(.name | endswith(".linux.tar.gz")) | .browser_download_url][0]')

iocage exec "$1" service lidarr stop

# Download and install the package
rm -Rf /usr/local/share/jackett
iocage exec "${1}" fetch -o /usr/local/share "${DOWNLOAD}"
iocage exec "$1" "tar -xzvf /usr/local/share/${FILE_NAME} -C /usr/local/share"
iocage exec "$1" rm /usr/local/share/"${FILE_NAME}"

iocage exec "$1" chown -R lidarr:lidarr /usr/local/share/lidarr /config
cp "${SCRIPT_DIR}"/blueprints/lidarr/includes/lidarr.rc /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/rc.d/lidarr
iocage exec "$1" chmod u+x /usr/local/etc/rc.d/lidarr
iocage exec "$1" service lidarr restart