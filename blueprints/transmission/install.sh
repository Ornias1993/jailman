#!/usr/local/bin/bash
# This file contains the install script for transmission

#init jail
initblueprint "$1"

# Initialise defaults

# Check if dataset Downloads dataset exist, create if they do not.
createmount "$1" "${global_dataset_downloads}" /mnt/downloads

# Check if dataset Complete Downloads dataset exist, create if they do not.
createmount "$1" "${global_dataset_downloads}"/complete /mnt/downloads/complete

# Check if dataset InComplete Downloads dataset exist, create if they do not.
createmount "$1" "${global_dataset_downloads}"/incomplete /mnt/downloads/incomplete


iocage exec "$1" chown -R transmission:transmission /config
iocage exec "$1" sysrc "transmission_enable=YES"
iocage exec "$1" sysrc "transmission_conf_dir=/config"
iocage exec "$1" sysrc "transmission_download_dir=/mnt/downloads/complete"
iocage exec "$1" service transmission restart

exitblueprint "$1" "Transmission is now accessible at http://${ip4_addr%/*}:9091"
