#!/usr/local/bin/bash

set -o errexit   # Exit on most errors
set -o errtrace  # Make sure any error trap is inherited
set -o nounset   # Disallow expansion of unset variables
set -o pipefail  # Use last non-zero exit code in a pipeline

trap "ERR during sabnzbd3 update" ERR

initblueprint "$1"

# stop service
iocage exec "$1" service sabnzbd stop

# download latest
latest_tarball_url=$(curl -qs https://api.github.com/repos/sabnzbd/sabnzbd/releases | jq '.[0].tarball_url')

target=/usr/local/share/sabnzbd3
iocage exec "$1" rm -rf $target
iocage exec "$1" mkdir -p $target
iocage exec "$1" "curl -qsL $latest_tarball_url | tar -xzf - --strip-components 1 -C $target"

# rebuild
iocage exec "$1" bash /root/build.sh $target

# service start will be done automatically by iocage restart, as it is enabled in rc.conf
