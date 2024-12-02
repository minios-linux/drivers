#!/bin/bash

set -e

KERNEL="6.1.119-mos"
ARCH="amd64"
MAINTAINER="MiniOS Kernel Team <team@minios.dev>"

META_VERSION=$(echo "$KERNEL" | grep -oP '^\d+\.\d+\.\d+')
KERNEL_VERSION=$(echo "$KERNEL" | grep -oP '^\d+\.\d+')

BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$BUILD_DIR/drivers.csv"

function display_help {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -d, --drivers       Build drivers only"
    echo "  -m, --meta          Build meta-package only"
    echo "  -h, --help          Display this help message"
    exit 0
}

BUILD_DRIVERS=true
BUILD_META=true

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d|--drivers) BUILD_META=false ;;
        -m|--meta) BUILD_DRIVERS=false ;;
        -h|--help) display_help ;;
        *) echo "Unknown parameter passed: $1"; display_help ;;
    esac
    shift
done

function build_drivers {
    apt -qq update
    MODULE_PACKAGES=()
    tail -n +2 "$FILE" | while IFS=';' read -r driver module version git; do
        DRIVER_DIR="$BUILD_DIR/$driver"
        [ -d "$DRIVER_DIR" ] && rm -rf "$DRIVER_DIR"
        git clone "$git" "$DRIVER_DIR"
        cd "$DRIVER_DIR" || exit 1
        cp -r "$BUILD_DIR/debian" .
        ARCHIVE_NAME="${driver}-modules-${KERNEL}-${ARCH}_${version}.orig.tar.xz"
        [ -f $ARCHIVE_NAME ] && rm -f $ARCHIVE_NAME
        bash debian/prepare.sh -d "$driver" -m "$module" -v "$version" -k "$KERNEL-$ARCH"
        apt -y build-dep .
        BUILD_METHOD=new dpkg-buildpackage -uc -us
        MODULE_PACKAGES+=("${driver}-modules-${KERNEL}-${ARCH}")
        cd "$BUILD_DIR"
    done
}

function build_meta_package {
    MODULE_PACKAGES=()
    while IFS=';' read -r driver module version git; do
        #echo "Read: driver=$driver, module=$module, version=$version, git=$git"
        MODULE_PACKAGES+=("${driver}-modules-${KERNEL}-${ARCH}")
    done < <(tail -n +2 "$FILE")

    #echo "Final MODULE_PACKAGES: ${MODULE_PACKAGES[@]}"

    META_PACKAGE_NAME="prebuilt-linux-modules-${KERNEL_VERSION}-mos-${ARCH}"
    META_PACKAGE_DIR="$BUILD_DIR/$META_PACKAGE_NAME"
    mkdir -p "$META_PACKAGE_DIR"
    cat <<EOL > "$META_PACKAGE_DIR/control"
Section: misc
Priority: optional
Standards-Version: 3.9.2
Package: prebuilt-linux-modules-${KERNEL_VERSION}-mos-${ARCH}
Version: $META_VERSION
Maintainer: $MAINTAINER
Architecture: $ARCH
Provides: prebuilt-linux-modules
Depends: $(IFS=,; echo "${MODULE_PACKAGES[*]}")
Description: Linux Kernel Modules (meta-package)
 This package installs kernel modules needed for
 various hardware components.
EOL
    equivs-build "$META_PACKAGE_DIR/control"
    rm -rf "$META_PACKAGE_DIR"
    echo "Meta-package $META_PACKAGE_NAME built successfully."
}

$BUILD_DRIVERS && build_drivers
$BUILD_META && build_meta_package
