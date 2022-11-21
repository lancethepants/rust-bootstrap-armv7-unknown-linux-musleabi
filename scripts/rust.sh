#!/bin/bash

set -e
set -x

BASE=`pwd`
SRC=$BASE/src
PATCHES=$BASE/patches
RPATH=$PREFIX/lib
DEST=$BASE$PREFIX
LDFLAGS="-L$DEST/lib -s -Wl,--dynamic-linker=$PREFIX/lib/ld-musl-$DESTARCH.so.1 -Wl,-rpath-link,$DEST/lib"
CPPFLAGS="-I$DEST/include"
CFLAGS=$EXTRACFLAGS
CXXFLAGS=$CFLAGS
CONFIGURE="./configure --prefix=$PREFIX --host=arm-tomatoware-linux-musleabi"
MAKE="make -j`nproc`"
export CCACHE_DIR=$HOME/.ccache_rust

########### #################################################################
# OPENSSL # #################################################################
########### #################################################################

OPENSSL_VERSION=1.1.1s

cd $SRC/openssl

if [ ! -f .extracted ]; then
	rm -rf openssl openssl-${OPENSSL_VERSION}
	tar zxvf openssl-${OPENSSL_VERSION}.tar.gz
	mv openssl-${OPENSSL_VERSION} openssl
	touch .extracted
fi

cd openssl

if [ ! -f .configured ]; then
	./Configure \
	linux-armv4 -march=armv7-a -mtune=cortex-a9 \
	$LDFLAGS \
	--prefix=$PREFIX
	touch .configured
fi

if [ ! -f .built ]; then
	make \
	CC=arm-tomatoware-linux-musleabi-gcc \
	AR=arm-tomatoware-linux-musleabi-ar \
	RANLIB=arm-tomatoware-linux-musleabi-ranlib
	touch .built
fi

if [ ! -f .installed ]; then
	make \
	install \
	CC=arm-tomatoware-linux-musleabi-gcc \
	AR=arm-tomatoware-linux-musleabi-ar \
	RANLIB=arm-tomatoware-linux-musleabi-ranlib \
	INSTALLTOP=$DEST \
	OPENSSLDIR=$DEST/ssl

	touch .installed
fi

######## ####################################################################
# RUST # ####################################################################
######## ####################################################################

RUST_VERSION=1.63.0
RUST_VERSION_REV=2

cd $SRC/rust

if [ ! -f .cloned ]; then
	git clone https://github.com/rust-lang/rust.git
	touch .cloned
fi

cd rust

if [ ! -f .configured ]; then
	git checkout $RUST_VERSION
	cp ../config.toml .
	touch .configured
fi

if [ ! -f .patched ]; then
	./x.py
#	./build/x86_64-unknown-linux-gnu/stage0/bin/cargo update -p libc
	touch .patched
fi

if [ ! -f .installed ]; then

	CARGO_TARGET_ARMV7_UNKNOWN_LINUX_MUSLEABI_RUSTFLAGS='-Ctarget-feature=-crt-static -Cstrip=symbols -Clink-arg=-Wl,--dynamic-linker=/mmc/lib/ld-musl-arm.so.1 -Clink-arg=-Wl,-rpath,/mmc/lib' \
	CFLAGS_armv7_unknown_linux_musleabi="-march=armv7-a -mtune=cortex-a9" \
	CXXFLAGS_armv7_unknown_linux_musleabi="-march=armv7-a -mtune=cortex-a9" \
	ARMV7_UNKNOWN_LINUX_MUSLEABI_OPENSSL_LIB_DIR=$DEST/lib \
	ARMV7_UNKNOWN_LINUX_MUSLEABI_OPENSSL_INCLUDE_DIR=$DEST/include \
	ARMV7_UNKNOWN_LINUX_MUSLEABI_OPENSSL_NO_VENDOR=1 \
	ARMV7_UNKNOWN_LINUX_MUSLEABI_OPENSSL_STATIC=1 \
	DESTDIR=$BASE/armv7-unknown-linux-musleabi \
	./x.py install
	touch .installed
fi

cd $BASE

if [ ! -f .prepped ]; then
	mkdir -p $BASE/armv7-unknown-linux-musleabi/DEBIAN
	cp $SRC/rust/control $BASE/armv7-unknown-linux-musleabi/DEBIAN
	sed -i 's,version,'"$RUST_VERSION"'-'"$RUST_VERSION_REV"',g' \
		$BASE/armv7-unknown-linux-musleabi/DEBIAN/control
	touch .prepped
fi

if [ ! -f .packaged ]; then
	dpkg-deb --build armv7-unknown-linux-musleabi
	dpkg-name armv7-unknown-linux-musleabi.deb
	touch .packaged
fi
