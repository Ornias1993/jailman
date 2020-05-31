#!/usr/local/bin/bash
# This file contains the update script for sonarr

#init jail
initblueprint "$1"

# Initialise defaults

iocage exec "$1" service sonarr stop

iocage exec "$1" rm -Rf /usr/local/share/NzbDrone
iocage exec "$1" "fetch http://download.sonarr.tv/v2/master/mono/NzbDrone.master.tar.gz -o /usr/local/share"
iocage exec "$1" "tar -xzvf /usr/local/share/NzbDrone.master.tar.gz -C /usr/local/share"
iocage exec "$1" rm /usr/local/share/NzbDrone.master.tar.gz

iocage exec "$1" chown -R sonarr:sonarr /usr/local/share/NzbDrone /config
cp "${SCRIPT_DIR}"/blueprints/sonarr/includes/sonarr.rc /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/rc.d/sonarr
iocage exec "$1" chmod u+x /usr/local/etc/rc.d/sonarr
iocage exec "$1" service sonarr restart