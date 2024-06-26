#!/bin/bash

set -e

KERNEL="6.1.90-mos"
#ARCH="amd64"

# Determine the directory path where this script is located
BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the file with drivers
FILE="$BUILD_DIR/drivers.csv"

# Architectures for packages and corresponding architectures of kernels
declare -A ARCHS
ARCHS=(["amd64"]="amd64")

apt -qq update

# Reading the file line by line, skipping the first header row
tail -n +2 "$FILE" | while IFS=';' read -r driver module version git; do

    if [ -d "$BUILD_DIR/$driver" ]; then
        rm -rf "$BUILD_DIR/$driver"
    fi
    # Cloning the repository
    git clone "$git" "$BUILD_DIR/$driver"

    # Change into the driver directory
    cd "$BUILD_DIR/$driver" || exit 1

    # Copying the debian folder to the current directory
    cp -r "$BUILD_DIR/debian" .

    # Executing commands for each architecture
    for ARCH in "${!ARCHS[@]}"; do
        KERNEL_ARCH=${ARCHS[$ARCH]}

        # Forming the name of the archive
        ARCHIVE_NAME="${driver}-modules-${KERNEL}-${KERNEL_ARCH}_${version}.orig.tar.xz"

        if [ -f $ARCHIVE_NAME ]; then
            rm -f $ARCHIVE_NAME
        fi

        # Executing a bash command with necessary parameters
        bash debian/prepare.sh -d "$driver" -m "$module" -v "$version" -k "$KERNEL-$KERNEL_ARCH"

        apt -y build-dep .

        # Building the package
        dpkg-buildpackage -uc -us
    done

    # Return to the directory of this script
    cd "$BUILD_DIR"
done
