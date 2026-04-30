#!/bin/sh
set -e

PWD=$(pwd)
SRC_DIR="$PWD/src"
BASE_BUILD_DIR="$PWD/build"
DOWNLOAD_DIR="$PWD/dl"

LIBUSB_VER="1.0.29"
LIBUSB_URL="https://github.com/libusb/libusb/releases/download/v${LIBUSB_VER}/libusb-${LIBUSB_VER}.tar.bz2"
ARCHS="x86_64 armv7 armv8"

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

# 🔥 🔥 🔥 关键：强制删除 netlink 检查代码
fix_libusb_configure() {
	cd "$LIBUSB_SOURCE"
	sed -i '/linux\/netlink.h/d' configure
	sed -i '/netlink.*required/d' configure
	sed -i '/AC_CHECK_HEADERS.*netlink/d' configure.ac
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

	if [ "$arch" = "x86_64" ]; then
		./configure --prefix="$LIBS_DIR" --disable-udev
	elif [ "$arch" = "armv7" ]; then
		./configure --prefix="$LIBS_DIR" --disable-udev --host=arm-linux-gnueabihf
	elif [ "$arch" = "armv8" ]; then
		./configure --prefix="$LIBS_DIR" --disable-udev --host=aarch64-linux-gnu
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

	if [ "$arch" = "x86_64" ]; then
		make CC="gcc" CONFIG_STATIC=yes LIBS_BASE="$LIBS_DIR"
		strip snander
	elif [ "$arch" = "armv7" ]; then
		make CC="arm-linux-gnueabihf-gcc" CONFIG_STATIC=yes LIBS_BASE="$LIBS_DIR"
		arm-linux-gnueabihf-strip snander
	elif [ "$arch" = "armv8" ]; then
		make CC="aarch64-linux-gnu-gcc" CONFIG_STATIC=yes LIBS_BASE="$LIBS_DIR"
		aarch64-linux-gnu-strip snander
	fi

	mv -f snander "$OUTPUT"
	make clean >/dev/null 2>&1
	echo "✅ 完成：$OUTPUT"
}

# ===================== 主流程 =====================
prepare_dirs
download_libusb
fix_libusb_configure  # 🔥 直接删掉 netlink 检查！

for arch in $ARCHS; do
	build_libusb "$arch"
	build_snander "$arch"
done

echo ""
echo "====================================="
echo " 🎉 全部编译成功！"
echo "====================================="
