#!/usr/bin/env bash

set -o errexit   # Exit on most errors
set -o errtrace  # Make sure any error trap is inherited
set -o nounset   # Disallow expansion of unset variables
set -o pipefail  # Use last non-zero exit code in a pipeline

trap "ERR during daapd build" ERR

# see config.yml for packages

# this does not work in a jail. is there an alternative?
# sh -c 'echo "fdesc      /dev/fd fdescfs rw      0       0" >> /etc/fstab'
# sh -c 'echo "proc       /proc   procfs  rw      0       0" >> /etc/fstab'
# mount /dev/fd
# mount /proc

WORKDIR=$(mktemp -d -t daapd)
CONFIG=/usr/local/etc/forked-daapd.conf
cd "$WORKDIR"

ENABLE64BIT="--enable-64bit"
PKG_CONFIG_PATH=/usr/local/lib:/usr/local/lib/pkgconfig:/usr/local/libdata/pkgconfig:/usr/local/ffmpeg/lib/pkgconfig
export PKG_CONFIG_PATH

wget -c --no-check-certificate https://github.com/antlr/website-antlr3/raw/gh-pages/download/antlr-3.4-complete.jar
wget -c --no-check-certificate https://github.com/antlr/website-antlr3/raw/gh-pages/download/C/libantlr3c-3.4.tar.gz

install antlr-3.4-complete.jar /usr/local/share/java
printf "#!/bin/sh
export CLASSPATH
CLASSPATH=\$CLASSPATH:/usr/local/share/java/antlr-3.4-complete.jar:/usr/local/share/java
/usr/local/bin/java org.antlr.Tool \$*
" > antlr3
install -m 755 antlr3 /usr/local/bin

tar xzf libantlr3c-3.4.tar.gz
cd libantlr3c-3.4
./configure $ENABLE64BIT && gmake -j8 && gmake install

cd "$WORKDIR"
git clone --depth 1 https://github.com/ejurgensen/forked-daapd.git
cd forked-daapd

autoreconf -vi

PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/local/ffmpeg/lib/pkgconfig"
export PKG_CONFIG_PATH

GEN_CFLAGS="-I/usr/include"
LOCAL_CFLAGS="-I/usr/local/include"

ZLIB_CFLAGS=$GEN_CFLAGS
ZLIB_LIBS="-lz"
export ZLIB_CFLAGS ZLIB_LIBS

CONFUSE_CFLAGS=$LOCAL_CFLAGS
CONFUSE_LIBS="-L/usr/local/lib -lconfuse"
export CONFUSE_CFLAGS
export CONFUSE_LIBS

MINIXML_CFLAGS=$LOCAL_CFLAGS
MINIXML_LIBS="-L/usr/local/lib -lmxml"
export MINIXML_CFLAGS MINIXML_LIBS

SQLITE3_CFLAGS=$LOCAL_CFLAGS
SQLITE3_LIBS="-L/usr/local/lib -lsqlite3"
export SQLITE3_CFLAGS SQLITE3_LIBS

LIBEVENT_CFLAGS=$LOCAL_CFLAGS
LIBEVENT_LIBS="-L/usr/local/lib -levent"
export LIBEVENT_CFLAGS LIBEVENT_LIBS

JSON_C_CFLAGS="-I/usr/local/include/json-c"
JSON_C_LIBS="-L/usr/local/lib -ljson-c"
export JSON_C_CFLAGS JSON_C_LIBS

LIBAV_CFLAGS="-I/usr/local/ffmpeg/include"
LIBAV_LIBS="-L/usr/local/ffmpeg/lib -aac -lasound -lavcodec -lavdevice -lavfilter -lavformat -lavutil -lfdk-aac -lpostproc -lswresample -lswscale -lx264 -lx265 -L/usr/local/lib -drm -lX11 -lXau -lXdmcp -lao -lbz2 -lc++ -ldl -lexpat -lfontconfig -lfreetype -lfribidi -lgcc -lgcc_s -liconv -llzma -lm -lpthread -lrt -lva -lvdpau -lxcb -lz -pthread -render -shape -shm -xfixes"

AVAHI_CFLAGS=$LOCAL_CFLAGS
AVAHI_LIBS="-L/usr/local/lib -lavahi-common -lavahi-client"
export AVAHI_CFLAGS AVAHI_LIBS

LIBPLIST_CFLAGS=$LOCAL_CFLAGS
LIBPLIST_LIBS="-L/usr/local/lib -lplist"
export LIBPLIST_CFLAGS LIBPLIST_LIBS

LIBSODIUM_CFLAGS=$LOCAL_CFLAGS
LIBSODIUM_LIBS="-L/usr/local/lib -lsodium"
export LIBSODIUM_CFLAGS LIBSODIUM_LIBS

LIBWEBSOCKETS_CFLAGS=$LOCAL_CFLAGS
LIBWEBSOCKETS_LIBS="-L/usr/local/lib -lwebsockets"
export LIBWEBSOCKETS_CFLAGS LIBWEBSOCKETS_LIBS

CFLAGS="-I/usr/local/include"
LDFLAGS="-L/usr/local/lib -lz -lmxml -ldns_sd -L/usr/local/ffmpeg/lib -lasound -lavcodec -lavdevice -lavfilter -lavformat -lavutil -lfdk-aac -lpostproc -lswresample -lswscale -lx264 -lx265"
export CFLAGS LDFLAGS

./configure && gmake -j8

if [ -f $CONFIG ]; then
    echo "Backing up old config file to $CONFIG.bak"
    cp "$CONFIG" "$CONFIG.bak"
fi
gmake install
sed -i -- 's/\/var\/cache/\/usr\/local\/var\/cache/g' $CONFIG

# Setup user and startup scripts
echo "daapd::::::forked-daapd:/nonexistent:/usr/sbin/nologin:" | adduser -w no -D -f -
chown -R daapd:daapd /usr/local/var/cache/forked-daapd
if [ ! -f scripts/freebsd_start_10.1.sh ]; then
    echo "Could not find FreeBSD startup script"
    exit
fi
install -m 755 scripts/freebsd_start_10.1.sh /usr/local/etc/rc.d/forked-daapd

