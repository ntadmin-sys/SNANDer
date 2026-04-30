#!/bin/sh
set -e

PWD=$(pwd)
SRC_DIR="$PWD/src"
BASE_BUILD_DIR="$PWD/build"
DOWNLOAD_DIR="$PWD/dl"

LIBUSB_VER="1.0.27"
LIBUSB_URL="https://github.com/libusb/libusb/releases/download/v${LIBUSB_VER}/libusb-${LIBUSB_VER}.tar.bz2"

ARCHS="x86 x86_64 armv7 armv8"

prepare_dirs() {
	mkdir -p "$DOWNLOAD_DIR"
}

download_libusb() {
	cd "$DOWNLOAD_DIR"
	if [ ! -d "libusb-${LIBUSB_VER}" ]; then
		if [ ! -f "libusb-${LIBUSB_VER}.tar.bz2" ]; then
			wget -O libusb-${LIBUSB_VER}.tar.bz2 "$LIBUSB_URL"
		fi
		tar xf libusb-${LIBUSB_VER}.tar.bz2
	fi
	LIBUSB_SOURCE="$DOWNLOAD_DIR/libusb-${LIBUSB_VER}"
}

build_libusb() {
	arch=$1
	BUILD_DIR="${BASE_BUILD_DIR}/${arch}"
	LIBS_DIR="${BUILD_DIR}/libs"
	mkdir -p "$LIBS_DIR"

	echo ""
	echo "====================================="
	echo "  编译 libusb [架构: $arch]"
	echo "====================================="

	cd "$LIBUSB_SOURCE"
	make distclean >/dev/null 2>&1 || true

	# 🔥 关键修复：--enable-netlink=no 彻底解决 netlink 报错
	if [ "$arch" = "x86" ]; then
		CFLAGS="-m32" LDFLAGS="-m32" ./configure --prefix="$LIBS_DIR" --disable-udev --enable-netlink=no --host=i686-linux-gnu
	elif [ "$arch" = "x86_64" ]; then
		./configure --prefix="$LIBS_DIR" --disable-udev --enable-netlink=no
	elif [ "$arch" = "armv7" ]; then
		./configure --prefix="$LIBS_DIR" --disable-udev --enable-netlink=no --host=arm-linux-gnueabihf
	elif [ "$arch" = "armv8" ]; then
		./configure --prefix="$LIBS_DIR" --disable-udev --enable-netlink=no --host=aarch64-linux-gnu
	fi

	make -j$(nproc)
	make install
	make distclean >/dev/null 2>&1 || true
}

build_snander() {
	arch=$1
	BUILD_DIR="${BASE_BUILD_DIR}/${arch}"
	LIBS_DIR="${BUILD_DIR}/libs"
	OUTPUT="${BASE_BUILD_DIR}/snander-${arch}"

	echo ""
	echo "====================================="
	echo "  编译 snander [架构: $arch]"
	echo "====================================="

	cd "$SRC_DIR"
	make clean >/dev/null 2>&1

	if [ "$arch" = "x86" ]; then
		make CC="gcc -m32" CONFIG_STATIC=yes LIBS_BASE="$LIBS_DIR"
		strip snander

	elif [ "$arch" = "x86_64" ]; then
		make CC="gcc" CONFIG_STATIC=yes LIBS_BASE="$LIBS_DIR"
		strip snander

	elif [ "$arch" = "armv7" ]; then
		make CC="arm-linux-gnueabihf-gcc" CONFIG_STATIC=yes LIBS_BASE="$LIBS_DIR" LDFLAGS_EXTRA="-static-libgcc"
		arm-linux-gnueabihf-strip snander

	elif [ "$arch" = "armv8" ]; then
		make CC="aarch64-linux-gnu-gcc" CONFIG_STATIC=yes LIBS_BASE="$LIBS_DIR" LDFLAGS_EXTRA="-static-libgcc"
		aarch64-linux-gnu-strip snander
	fi

	mv -f snander "$OUTPUT"
	make clean >/dev/null 2>&1
	echo "✅ 完成：$OUTPUT"
}

# ===================== 主流程 =====================
prepare_dirs
download_libusb

for arch in $ARCHS; do
	build_libusb "$arch"
	build_snander "$arch"
done

echo ""
echo "====================================="
echo " 🎉 全架构编译完成！"
echo "====================================="
