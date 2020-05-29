#!/usr/local/bin/bash
# This file contains the update script for forked_daapd

set -o errexit   # Exit on most errors
set -o errtrace  # Make sure any error trap is inherited
set -o nounset   # Disallow expansion of unset variables
set -o pipefail  # Use last non-zero exit code in a pipeline

trap "ERR during forked-daapd update" ERR

iocage exec "$1" service dbus stop
iocage exec "$1" service avahi-daemon stop
iocage exec "$1" service forked-daapd stop

# ensure build dependencies are installed
iocage exec "$1" pkg install -y autoconf automake autotools cmake curl git gmake gperf iconv libtool mercurial nasm opus rsync wget yasm

iocage exec "$1" bash /root/build-ffmpeg.sh
iocage exec "$1" bash /root/build-daapd.sh

# remove build depdendencies
iocage exec "$1" pkg delete -y autoconf automake autotools cmake curl git gmake gperf iconv libtool mercurial nasm opus rsync wget yasm

iocage exec "$1" chown -R daapd:daapd /config

iocage exec "$1" sysrc "dbus_enable=YES"
iocage exec "$1" sysrc "avahi_daemon_enable=YES"
iocage exec "$1" sysrc "forked_daapd_flags=-c /config/forked-daapd.conf"
iocage exec "$1" sysrc "forked_daapd_enable=YES"

iocage exec "$1" service dbus start
iocage exec "$1" service avahi-daemon start
iocage exec "$1" service forked-daapd start

iocage exec "$1" service dbus restart
iocage exec "$1" service avahi-daemon restart
iocage exec "$1" service forked-daapd restart

