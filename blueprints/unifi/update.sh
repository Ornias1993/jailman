#!/usr/local/bin/bash
# This file contains the update script for unifi
# Unifi Controller is updated through pkg, Unifi-Poller is not. This script updates Unifi-Poller

#init jail
initblueprint "$1"

if [[ ! "${poller}" ]]; then
	echo "Skipping Unifi Poller for update, not installed"
else
	FILE_NAME=$(curl -s https://api.github.com/repos/unifi-poller/unifi-poller/releases/latest | jq -r ".assets[] | select(.name | contains(\"amd64.txz\")) | .name")
	DOWNLOAD=$(curl -s https://api.github.com/repos/unifi-poller/unifi-poller/releases/latest | jq -r ".assets[] | select(.name | contains(\"amd64.txz\")) | .browser_download_url")
	
	# Check to see if there is an update.
	if [[ -f /mnt/"${global_dataset_config}"/"${1}"/"${FILE_NAME}" ]]; then
		echo "Unifi-Poller is up to date."
		exit 1
	else
		# Download and install the package
		iocage exec "${1}" fetch -o /config "${DOWNLOAD}"
		iocage exec "${1}" pkg install -qy /config/"${FILE_NAME}"
		iocage exec "${1}" service unifi_poller restart
	fi
fi
iocage exec "${1}" service unifi restart
echo "Update complete!"
