#!/usr/local/bin/bash

initblueprint "$1"

# Check if (in)complete download datasets exist, create if they do not.
createmount "$1" "${global_dataset_downloads}" /mnt/downloads
createmount "$1" "${global_dataset_downloads}"/complete /mnt/downloads/complete
createmount "$1" "${global_dataset_downloads}"/incomplete /mnt/downloads/incomplete

# setup sabnzbd service
iocage exec "$1" chown -R _sabnzbd:_sabnzbd /config
iocage exec "$1" sysrc "sabnzbd_enable=YES"
iocage exec "$1" sysrc "sabnzbd_conf_dir=/config"
iocage exec "$1" sysrc "sabnzbd_user=_sabnzbd"
iocage exec "$1" sysrc "sabnzbd_group=_sabnzbd"

# start once to let service write default config
iocage exec "$1" service sabnzbd start
iocage exec "$1" service sabnzbd stop
# put our config in place
iocage exec "$1" sed -i '' -e 's?host = 127.0.0.1?host = 0.0.0.0?g' /config/sabnzbd.ini
iocage exec "$1" sed -i '' -e 's?download_dir = Downloads/incomplete?download_dir = /mnt/downloads/incomplete?g' /config/sabnzbd.ini
iocage exec "$1" sed -i '' -e 's?complete_dir = Downloads/complete?complete_dir = /mnt/downloads/complete?g' /config/sabnzbd.ini

iocage exec "$1" service sabnzbd start

exitblueprint "$1"
