#!/usr/local/bin/bash
# This file contains an example install script to base your own jails on

set -o errexit   # Exit on most errors
set -o errtrace  # Make sure any error trap is inherited
set -o nounset   # Disallow expansion of unset variables
set -o pipefail  # Use last non-zero exit code in a pipeline

trap "ERR during sabnzbd3 install" ERR

initblueprint "$1"

createmount "$1" "${global_dataset_downloads}" /mnt/downloads
createmount "$1" "${global_dataset_downloads}"/complete /mnt/downloads/complete
createmount "$1" "${global_dataset_downloads}"/incomplete /mnt/downloads/incomplete

target=/usr/local/share/sabnzbd3
latest_tarball_url=$(curl -qs https://api.github.com/repos/sabnzbd/sabnzbd/releases | jq '.[0].tarball_url')

iocage exec "$1" mkdir -p $target
iocage exec "$1" "curl -qsL $latest_tarball_url | tar -xzf - --strip-components 1 -C $target"
cp "${includes_dir}"/build.sh "${jail_root}"/root/
iocage exec "$1" bash /root/build.sh $target
cp "${includes_dir}"/sabnzbd3.rc "${jail_root}"/usr/local/etc/rc.d/sabnzbd
iocage exec "$1" chmod +x /usr/local/etc/rc.d/sabnzbd
iocage exec "$1" pw user add sabnzbd -c sabnzbd -d /nonexistent -s /usr/bin/nologin
iocage exec "$1" chown -R sabnzbd:sabnzbd  /config
iocage exec "$1" sysrc "sabnzbd_enable=YES"

# start once to let service write default config
iocage exec "$1" service sabnzbd start
iocage exec "$1" service sabnzbd stop

# put our config in place
iocage exec "$1" sed -i '' -e 's?host = 127.0.0.1?host = 0.0.0.0?g' /config/sabnzbd.ini
iocage exec "$1" sed -i '' -e 's?download_dir = Downloads/incomplete?download_dir = /mnt/downloads/incomplete?g' /config/sabnzbd.ini
iocage exec "$1" sed -i '' -e 's?complete_dir = Downloads/complete?complete_dir = /mnt/downloads/complete?g' /config/sabnzbd.ini

iocage exec "$1" service sabnzbd start

exitblueprint "$1" "SABnzbd3 is now available at http://${jail_ip}:8080/"
