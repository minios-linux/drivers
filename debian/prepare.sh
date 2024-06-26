#!/bin/sh

# A function to display a usage message
usage() {
    echo "Usage: $0 -d <driverName> -m <moduleName> -v <driverVersion> -k <kernelVersion>"
    exit 1
}

# Use getopts to handle command line arguments
while getopts "d:m:v:k:" opt; do
    case $opt in
    d) DRIVER_NAME="$OPTARG" ;;    # Driver Name
    m) MODULE_NAME="$OPTARG" ;;    # Module Name
    v) DRIVER_VERSION="$OPTARG" ;; # Driver Version
    k) KERNEL_VERSION="$OPTARG" ;; # Kernel Version
    *) usage ;;                    # If unknown option, output usage message
    esac
done

# Check that all options were specified
if [ -z "$DRIVER_NAME" ] || [ -z "$MODULE_NAME" ] || [ -z "$DRIVER_VERSION" ] || [ -z "$KERNEL_VERSION" ]; then
    usage
fi

SCRIPT_DIR="$(dirname "$(realpath "$0")")" # Get the directory where the script is located
echo "Script directory: $SCRIPT_DIR"

if [ "$(basename "$SCRIPT_DIR")" = "debian" ]; then
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")" # if the script is in debian, the parent directory will be the project folder
else
    PROJECT_DIR="$SCRIPT_DIR" # otherwise, the script's directory is the project's directory
fi

echo "Project directory: $PROJECT_DIR"

PROJECT_NAME="$(basename "$PROJECT_DIR")" # Get project name
echo "Project name: $PROJECT_NAME"

PARENT_DIR="$(dirname "$PROJECT_DIR")" # Parent directory of the project directory
echo "Parent directory: $PARENT_DIR"

# Forming the name of the archive
ARCHIVE_NAME="${DRIVER_NAME}-modules-${KERNEL_VERSION}_${DRIVER_VERSION}.orig.tar.xz"
echo "Archive name: $ARCHIVE_NAME"

echo "Starting archive creation..."
tar -cJf "${PARENT_DIR}/${ARCHIVE_NAME}" --exclude="./debian" -C "${PROJECT_DIR}" . # Create tar.xz archive, excluding the debian folder

if [ $? -eq 0 ]; then
    echo "Archive created successfully at ${PARENT_DIR}/${ARCHIVE_NAME}"
else
    echo "Failed to create archive"
    exit 1
fi

# File modification
echo "Starting file modification..."
cd "$PROJECT_DIR/debian/templates" || exit

DATETIME="$(date '+%a, %d %b %Y %T %z')" # Get current datetime in required format

for file in *; do
    # Use sed to replace placeholders in the template
    sed -i.bak \
        -e "s/<kernel>/${KERNEL_VERSION}/g" \
        -e "s/<driver>/${DRIVER_NAME}/g" \
        -e "s/<DRIVER>/$(echo ${DRIVER_NAME} | tr '[:lower:]' '[:upper:]')/g" \
        -e "s/<module>/${MODULE_NAME}/g" \
        -e "s/<version>/${DRIVER_VERSION}/g" \
        -e "s|<datetime>|${DATETIME}|g" "$file"

    # Check if the sed operation succeeded
    if [ $? -eq 0 ]; then
        echo "Modified file $file successfully"

        # Copy the modified file to the debian directory
        cp "$file" "$PROJECT_DIR/debian/$file"

        if [ $? -eq 0 ]; then
            echo "Copied modified file $file to debian directory"

            # Restore the file from the backup
            mv "${file}.bak" "$file"

            if [ $? -eq 0 ]; then
                echo "Restored the original of $file from its backup"
            else
                echo "Failed to restore file $file from its backup"
                exit 1
            fi
        else
            echo "Failed to copy file $file"
            exit 1
        fi
    else
        echo "Failed to modify file $file"
        exit 1
    fi
done
