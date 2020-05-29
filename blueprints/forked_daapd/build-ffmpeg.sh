#!/usr/bin/env bash

# This is based on a script by Glorious1 and HJD from
# https://www.ixsystems.com/community/threads/how-to-install-ffmpeg-in-a-jail.39818/
# It was modified to build on 11.3 and run without user input by asmod3us.

set -o errexit   # Exit on most errors
set -o errtrace  # Make sure any error trap is inherited
set -o nounset   # Disallow expansion of unset variables
set -o pipefail  # Use last non-zero exit code in a pipeline

trap "ERR during ffmpeg build" ERR

CORES=$(sysctl -n hw.ncpu)

# see config.yml for packages

export CC=/usr/bin/clang
export CXX=/usr/bin/clang++
export PATH=$PATH:/usr/local/share
export PKG_CONFIG_PATH=/usr/local/lib:/usr/local/lib/pkgconfig:/usr/local/libdata/pkgconfig

BUILD=$(mktemp -d -t ffmpeg)
TARGET=/usr/local/ffmpeg
export PATH=$PATH:${TARGET}/bin

rm -f /usr/local/lib/libavcodec* /usr/local/lib/libx2*

mkdir -p "${BUILD}" ${TARGET}

git clone --depth 1 https://github.com/mstorsjo/fdk-aac "$BUILD"/fdk-aac/
git clone --depth 1 https://anongit.freedesktop.org/git/pkg-config "$BUILD"/pkg-config/
git clone --depth 1 http://git.videolan.org/git/x264.git "$BUILD"/x264/
hg clone http://hg.videolan.org/x265 "$BUILD"/x265/
git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git "$BUILD"/ffmpeg/

cd "$BUILD"/fdk-aac
# There is no configure file anymore so have to make it with autoreconf
autoreconf -fiv && \
./configure --prefix="$TARGET" --disable-shared && \
make -j"$CORES" && \
make install

cd "$BUILD"/pkg-config
sed -i '' -e 's/m4_copy(/m4_copy_force(/' glib/m4macros/glib-gettext.m4
./autogen.sh --with-internal-glib --prefix="$TARGET" --exec-prefix="$TARGET"
make -j"$CORES" install clean

export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$TARGET/lib/pkgconfig

cd "$BUILD"/x264

sed -i '' -e 's|#\!/bin/bash|#\!/usr/bin/env bash|' configure
./configure --prefix=$TARGET --enable-static --enable-pic
gmake -j"$CORES"
gmake install clean

cd "$BUILD"/x265/build/linux

# shellcheck disable=SC2016
sed -i '' -E \
-e '/cd 12bit/,/cmake/ s|^cmake|cmake -D CMAKE_C_COMPILER=/usr/bin/clang -D CMAKE_CXX_COMPILER=/usr/bin/clang++|' \
-e '/cd \.\.\/8bit/,/cmake/ s|^cmake \.\./\.\./\.\./source|cmake -DCMAKE_INSTALL_PREFIX=/usr/local/ffmpeg/ ../../../source -DENABLE_SHARED=OFF|' \
-e 's/cmake/cmake -j'"$CORES"'/' \
-e 's/(if \[ "\$uname" = "Linux" \])/\1 | [ "$uname" = "FreeBSD" ]/' multilib.sh

./multilib.sh
cd 8bit
make -j"$CORES" install

cp -v ${TARGET}/lib/libx265* /usr/local/lib
cd "$BUILD"/ffmpeg

export CFLAGS="-I${TARGET}/include -I/usr/local/include -I/usr/include"
export LDFLAGS="-L${TARGET}/lib -L/usr/local/lib -L/usr/lib"
export PKG_CONFIG_PATH=${TARGET}/lib:$TARGET/lib/pkgconfig:${PKG_CONFIG_PATH}

./configure prefix=$TARGET --cc=/usr/bin/clang \
--extra-cflags="-I$TARGET/include" --extra-ldflags="-L$TARGET/lib" \
--extra-libs=-lpthread \
--pkg-config-flags="--static" \
--enable-static --disable-shared --enable-libfdk-aac --enable-libx264 \
--enable-libx265 --enable-libfreetype --enable-libfontconfig \
--enable-libfribidi --enable-nonfree --enable-gpl --enable-version3 \
--enable-hardcoded-tables --enable-avfilter --enable-filters --disable-outdevs \
--disable-network --enable-libopus --enable-libsoxr

gmake -j"$CORES"
gmake install

