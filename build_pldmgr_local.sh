#!/usr/bin/env bash
# 在本项目里用本地 PS5 Payload SDK 编译内置的 payload-manager（pldmgr）
#
# 不依赖 Docker（上游 build_release.sh 走的是 Docker，本机没有）。
# 编完把 pldmgr.elf 放到仓库根目录，供 autoloader 通过 xxd 内嵌。
#
# 一次性准备依赖：
#   ~/sdk/ps5-build/pldmgr-deps/build_deps_local.sh
#   → 生成 ~/sdk/ps5-build/pldmgr-deps/prefix（libmicrohttpd + mbedTLS + curl）
#
# 用法：
#   ./build_pldmgr_local.sh           # 编译 + 复制到 ./pldmgr.elf
#   ./build_pldmgr_local.sh --only    # 只编到子模块目录，不复制
#
# 环境变量：
#   PS5_PAYLOAD_SDK   默认 ~/sdk/ps5-payload-sdk
#   PLDMGR_DEPS       默认 ~/sdk/ps5-build/pldmgr-deps/prefix
#   LLVM_CONFIG       默认 /opt/homebrew/opt/llvm@18/bin/llvm-config
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

SDK="${PS5_PAYLOAD_SDK:-/Users/chenpy/sdk/ps5-payload-sdk}"
DEPS="${PLDMGR_DEPS:-$HOME/sdk/ps5-build/pldmgr-deps/prefix}"
SUB="third_party/ps5-payload-manager"

[ -d "$SDK" ] || { echo "ERROR: 找不到 SDK: $SDK"; exit 1; }
[ -f "$DEPS/lib/libcurl.a" ] || {
    echo "ERROR: 缺少依赖库: $DEPS/lib/libcurl.a"
    echo "       先跑: ~/sdk/ps5-build/pldmgr-deps/build_deps_local.sh"
    exit 1; }
[ -e "$SUB/.git" ] || {
    echo "ERROR: 子模块未初始化。先跑:"
    echo "       git submodule update --init --recursive"
    exit 1; }

# prospero-llvm-config 靠 llvm-config 定位 clang，必须显式给
export LLVM_CONFIG="${LLVM_CONFIG:-/opt/homebrew/opt/llvm@18/bin/llvm-config}"
[ -x "$LLVM_CONFIG" ] || { echo "ERROR: 找不到 llvm-config: $LLVM_CONFIG"; exit 1; }

# 前端资源（生成 include/assets_*.h）是编译前提
if [ ! -f "$SUB/frontend/dist/index.html" ]; then
    echo "=== 前端未构建，先跑 frontend-build ==="
    make -C "$SUB" frontend-build
    echo
fi

INCLUDES="-Iinclude -I$SDK/target/include -I$DEPS/include"
LIBS="$DEPS/lib/libcurl.a \
      $DEPS/lib/libmbedtls.a $DEPS/lib/libmbedx509.a $DEPS/lib/libmbedcrypto.a \
      $DEPS/lib/libmicrohttpd.a \
      -L$SDK/target/lib -lpthread \
      -lSceNetCtl -lSceUserService -lSceSystemService \
      -lSceAppInstUtil -lSceHttp2 -lSceSsl -lSceNet"

echo "=== 项目 : $ROOT"
echo "=== SDK  : $SDK"
echo "=== DEPS : $DEPS"
echo

# 子模块 Makefile 把 SDK 写死成 /opt/ps5-payload-sdk，LIBS 也写死成 mbedTLS 那一组，
# 所以这里整行覆盖 SDK / CC / STRIP / INCLUDES / LIBS
make -C "$SUB" \
     SDK="$SDK" \
     CC="$SDK/bin/prospero-clang" \
     STRIP="$SDK/bin/prospero-strip" \
     INCLUDES="$INCLUDES" \
     LIBS="$LIBS" \
     clean all

echo
echo "=== 产物 ==="
ls -lh "$SUB/pldmgr.elf"
file "$SUB/pldmgr.elf"
strings "$SUB/pldmgr.elf" | grep -m1 -oE 'Payload Manager v[0-9.]+ by PLK' || true

if [ "$1" != "--only" ]; then
    cp "$SUB/pldmgr.elf" "$ROOT/pldmgr.elf"
    echo
    echo "=== 已复制到 $ROOT/pldmgr.elf ==="
    echo "    接着编 autoloader:  make clean all"
fi
