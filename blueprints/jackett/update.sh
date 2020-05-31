#!/usr/local/bin/bash
# This file contains the update script for jackett

#init jail
initblueprint "$1"

# Initialise defaults
FILE_NAME=$(curl -s https://api.github.com/repos/Jackett/Jackett/releases/latest | jq -r ".assets[] | select(.name | contains(\"Mono.tar.gz\")) | .name")
DOWNLOAD=$(curl -s https://api.github.com/repos/Jackett/Jackett/releases/latest | jq -r ".assets[] | select(.name | contains(\"Mono.tar.gz\")) | .browser_download_url")

iocage exec "$1" service jackett stop

# Download and install the package
rm -Rf /usr/local/share/jackett
iocage exec "${1}" fetch -o /usr/local/share "${DOWNLOAD}"
iocage exec "$1" "tar -xzvf /usr/local/share/${FILE_NAME} -C /usr/local/share"
iocage exec "$1" rm /usr/local/share/"${FILE_NAME}"

iocage exec "$1" chown -R jackett:jackett /usr/local/share/Jackett /config
cp "${SCRIPT_DIR}"/blueprints/jackett/includes/jackett.rc /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/rc.d/jackett
iocage exec "$1" chmod u+x /usr/local/etc/rc.d/jackett
iocage exec "$1" service jackett restart
