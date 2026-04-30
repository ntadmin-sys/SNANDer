#!/bin/sh
set -e

# ===================== 配置区 =====================
PWD=$(pwd)
SRC_DIR="$PWD/src"
BASE_BUILD_DIR="$PWD/build"
DOWNLOAD_DIR="$PWD/dl"

# libusb 版本
LIBUSB_VER="1.0.27"
LIBUSB_URL="https://github.com/libusb/libusb/releases/download/v${LIBUSB_VER}/libusb-${LIBUSB_VER}.tar.bz2"

# 支持的架构列表（可自由增删）
ARCHS="x86 x86_64 armv7 armv8"

# 交叉编译工具链前缀（根据你的系统安装对应工具）
# Ubuntu/Debian 可直接安装：
# sudo apt install gcc-multilib g++-multilib gcc-arm-linux-gnueabihf gcc-aarch64-linux-gnu
TOOLCHAIN_x86="i686-linux-gnu-"
TOOLCHAIN_x86_64=""
TOOLCHAIN_armv7="arm-linux-gnueabihf-"
TOOLCHAIN_armv8="aarch64-linux-gnu-"

# ===================== 工具函数 =====================
prepare_dirs() {
    mkdir -p "$DOWNLOAD_DIR"
}

# 下载并解压 libusb 源码（只下载一次）
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

# 编译 libusb 对应架构
build_libusb() {
    local arch=$1
    local tc_var="TOOLCHAIN_$arch"
    local TOOLCHAIN=${!tc_var}

    local BUILD_DIR="${BASE_BUILD_DIR}/${arch}"
    local LIBS_DIR="${BUILD_DIR}/libs"

    echo -e "\n====================================="
    echo "  编译 libusb [架构: $arch]"
    echo "====================================="

    mkdir -p "$LIBS_DIR"
    cd "$LIBUSB_SOURCE"
    make distclean >/dev/null 2>&1 || true

    # 交叉编译配置
    if [ "$arch" = "x86" ]; then
        export CFLAGS="-m32"
        export LDFLAGS="-m32"
        ./configure --prefix="$LIBS_DIR" --disable-udev --host=i686-linux-gnu
    elif [ "$arch" = "x86_64" ]; then
        ./configure --prefix="$LIBS_DIR" --disable-udev
    elif [ "$arch" = "armv7" ]; then
        ./configure --prefix="$LIBS_DIR" --disable-udev --host=arm-linux-gnueabihf
    elif [ "$arch" = "armv8" ]; then
        ./configure --prefix="$LIBS_DIR" --disable-udev --host=aarch64-linux-gnu
    fi

    make -j$(nproc)
    make install
    make distclean >/dev/null 2>&1 || true

    unset CFLAGS LDFLAGS
}

# 编译目标项目 snander 对应架构
build_snander() {
    local arch=$1
    local tc_var="TOOLCHAIN_$arch"
    local TOOLCHAIN=${!tc_var}

    local BUILD_DIR="${BASE_BUILD_DIR}/${arch}"
    local LIBS_DIR="${BUILD_DIR}/libs"
    local OUTPUT="${BASE_BUILD_DIR}/snander-${arch}"

    echo -e "\n====================================="
    echo "  编译 snander [架构: $arch]"
    echo "====================================="

    cd "$SRC_DIR"
    make clean >/dev/null 2>&1

    # 交叉编译
    if [ "$arch" = "x86" ]; then
        make CC="${TOOLCHAIN}gcc -m32" CXX="${TOOLCHAIN}g++ -m32" \
             CONFIG_STATIC=yes LIBS_BASE="$LIBS_DIR" strip
    else
        make CC="${TOOLCHAIN}gcc" CXX="${TOOLCHAIN}g++" \
             CONFIG_STATIC=yes LIBS_BASE="$LIBS_DIR" strip
    fi

    # 移动最终文件
    mv -f snander "$OUTPUT"
    make clean >/dev/null 2>&1

    echo "✅ 完成：$OUTPUT"
}

# ===================== 主流程 =====================
prepare_dirs
download_libusb

# 遍历所有架构编译
for arch in $ARCHS; do
    build_libusb "$arch"
    build_snander "$arch"
done

echo -e "\n====================================="
echo " 🎉 所有架构编译完成！"
echo " 输出文件位于：$BASE_BUILD_DIR/"
echo " 文件名：snander-x86 / snander-x86_64 / snander-armv7 / snander-armv8"
echo "====================================="
