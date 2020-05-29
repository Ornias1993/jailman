#!/usr/local/bin/bash
# This script builds and installs the current release of forked_daapd

set -o errexit   # Exit on most errors
set -o errtrace  # Make sure any error trap is inherited
set -o nounset   # Disallow expansion of unset variables
set -o pipefail  # Use last non-zero exit code in a pipeline

trap "ERR during forked-daapd install" ERR

initblueprint "$1"

createmount "$1" "${itunes_media}" /media/itunes

# shellcheck disable=SC2154

cp "${SCRIPT_DIR}"/blueprints/forked_daapd/build-ffmpeg.sh /mnt/"${global_dataset_iocage}"/jails/"$1"/root/root/
cp "${SCRIPT_DIR}"/blueprints/forked_daapd/build-daapd.sh /mnt/"${global_dataset_iocage}"/jails/"$1"/root/root/

iocage exec "$1" pkg install -y autoconf automake autotools cmake git glib gmake gperf iconv libtool mercurial mxml nasm opus rsync wget yasm

iocage exec "$1" bash /root/build-ffmpeg.sh
iocage exec "$1" bash /root/build-daapd.sh

# default config: /usr/local/etc/forked-daapd.conf
iocage exec "$1" cp /usr/local/etc/forked-daapd.conf /config/
iocage exec "$1" chown -R daapd:daapd /config

# set itunes lib
# enable websocket port
# set db path
iocage exec "$1" sed -i '' \
	-e "/directories =/s?=.*?= { \"/media/itunes\" }?" \
	-e "/#[[:space:]]*websocket_port =/s?#\([^=]*\) =.*?\1 = 3688?" \
	-e "/#[[:space:]]*cache_path =/s?#\([^=]*\) =.*?\1 = /config/cache.db?" \
	-e "/#[[:space:]]*db_path =/s?#\([^=]*\) =.*?\1 = /config/songs3.db?" /config/forked-daapd.conf

iocage exec "$1" sysrc "dbus_enable=YES"
iocage exec "$1" sysrc "avahi_daemon_enable=YES"
iocage exec "$1" sysrc "forked_daapd_flags=-c /config/forked-daapd.conf"
iocage exec "$1" sysrc "forked_daapd_enable=YES"

iocage exec "$1" service dbus start
iocage exec "$1" service avahi-daemon start
iocage exec "$1" service forked-daapd start

JAIL_IP=${ip4_addr:-}
if [ -z "${JAIL_IP}" ]; then
	DEFAULT_IF=$(iocage exec "$1" route get default | awk '/interface/ {print $2}')
	JAIL_IP=$(iocage exec "$1" ifconfig "$DEFAULT_IF" | awk '/inet/ { print $2 }')
else
	JAIL_IP=${ip4_addr%/*}
fi

exitblueprint "$1" "forked-daapd is available at http://${JAIL_IP}:3689/ and via daap."
