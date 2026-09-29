#!/usr/bin/env bash
# ps5-unified-autoloader — Versioned Build Script
#
# Usage:
#   ./build_release.sh              # build pldmgr locally with the PS5 Payload SDK (default)
#   ./build_release.sh -d           # download pre-built pldmgr.elf from GitHub releases
#   ./build_release.sh --download-deps
#   ./build_release.sh -b           # build pldmgr from source inside Docker
#   ./build_release.sh --build-deps
#
# 默认走本地 SDK：调用同目录下的 build_pldmgr_local.sh。
# 依赖需先备好（一次性）：
#   ~/sdk/ps5-build/pldmgr-deps/build_deps_local.sh
set -e
cd "$(dirname "$0")"

# -----------------------------------------------------------------------
# Parse flags
# -----------------------------------------------------------------------
DEP_ACTION="local"  # default: 用本地 SDK 编译 pldmgr

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --build-deps|-b)    DEP_ACTION="build" ;;
        --download-deps|-d) DEP_ACTION="download" ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# -----------------------------------------------------------------------
# Extract version from include/autoloader.h
# -----------------------------------------------------------------------
VERSION=$(grep '#define AUTOLOADER_VERSION' include/autoloader.h \
    | awk '{print $3}' | tr -d '"' | tr -d '\r')

if [ -z "$VERSION" ]; then
    echo "Error: Could not find AUTOLOADER_VERSION in include/autoloader.h"
    exit 1
fi

# -----------------------------------------------------------------------
# Compute short commit hash (or DEV_<timestamp> if working tree is dirty)
# -----------------------------------------------------------------------
if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    SHORT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
else
    SHORT_HASH="DEV_$(date -u +"%Y%m%d_%H%M%S")"
fi

OUTPUT_ELF="autoloader_v${VERSION}_${SHORT_HASH}.elf"

echo "=== ps5-unified-autoloader v${VERSION} (${SHORT_HASH}) ==="

# -----------------------------------------------------------------------
# Step 1: Obtain pldmgr.elf
# -----------------------------------------------------------------------
if [ "$DEP_ACTION" = "local" ]; then
    echo "[1/2] Building pldmgr locally with the PS5 Payload SDK..."

    if [ ! -e "third_party/ps5-payload-manager/.git" ]; then
        echo "      Error: ps5-payload-manager submodule not initialised."
        echo "      Run: git submodule update --init --recursive"
        exit 1
    fi

    if [ ! -x "./build_pldmgr_local.sh" ]; then
        echo "      Error: ./build_pldmgr_local.sh not found or not executable."
        echo "      Use ./build_release.sh -d to download the pre-built pldmgr.elf instead."
        exit 1
    fi

    ./build_pldmgr_local.sh

    if [ ! -f "pldmgr.elf" ]; then
        echo "      Error: local build finished but pldmgr.elf not found."
        exit 1
    fi
    echo "      pldmgr.elf built locally: $(ls -lh pldmgr.elf | awk '{print $5}')"

elif [ "$DEP_ACTION" = "build" ]; then
    echo "[1/2] Building pldmgr from source (Docker)..."

    if [ ! -e "third_party/ps5-payload-manager/.git" ]; then
        echo "      Error: ps5-payload-manager submodule not initialised."
        echo "      Run: git submodule update --init --recursive"
        exit 1
    fi

    (cd third_party/ps5-payload-manager && ./build_release.sh)

    PLDMGR_ELF=$(ls third_party/ps5-payload-manager/pldmgr_v*.elf 2>/dev/null | head -n 1)
    if [ -z "$PLDMGR_ELF" ]; then
        echo "      Error: pldmgr build succeeded but no versioned ELF found."
        exit 1
    fi

    cp "$PLDMGR_ELF" pldmgr.elf
    echo "      pldmgr.elf obtained from source build: $(basename "$PLDMGR_ELF")"

else
    echo "[1/2] Downloading pre-built pldmgr.elf from GitHub releases..."

    PLDMGR_URL=$(curl -s https://api.github.com/repos/itsPLK/ps5-payload-manager/releases/latest \
        | grep "browser_download_url" \
        | grep 'pldmgr_v.*\.elf"' \
        | head -n 1 \
        | sed 's/.*"browser_download_url": "\(.*\)".*/\1/')

    if [ -z "$PLDMGR_URL" ]; then
        echo "      Error: Could not find pldmgr release URL."
        echo "      Try running without -d to build pldmgr locally instead."
        exit 1
    fi

    echo "      Downloading: $PLDMGR_URL"
    curl -L -o pldmgr.elf "$PLDMGR_URL"
    echo "      pldmgr.elf downloaded."
fi

# -----------------------------------------------------------------------
# Step 2: Build autoloader.elf with the locally installed SDK
# -----------------------------------------------------------------------
echo "[2/2] Building autoloader.elf with local SDK..."
make clean all

# -----------------------------------------------------------------------
# Rename to versioned output
# -----------------------------------------------------------------------
if [ ! -f "autoloader.elf" ]; then
    echo "Error: autoloader.elf not found after build."
    exit 1
fi

mv autoloader.elf "$OUTPUT_ELF"
echo ""
echo "=== Build complete! ==="
echo "    Output: $OUTPUT_ELF"
