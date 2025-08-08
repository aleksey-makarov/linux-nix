#!/usr/bin/env bash

DATE=$(date '+%y%m%d%H%M%S')
BUILD_DIR=$(realpath "linux.$DATE")
LINUX_DIR=$(realpath "linux")
LINUX_MIRROR_DIR="/local/mnt/workspace/amakarov/src/linux.git"

if [ ! -e "$LINUX_DIR" ] ; then
    echo "Creating $LINUX_DIR"
    git clone --no-checkout "$LINUX_MIRROR_DIR" "$LINUX_DIR"
    cd "$LINUX_DIR" || exit 1
    git checkout -b linux-master v6.12.40
    cd - || exit 1
else
    echo "Using existing $LINUX_DIR"
fi

mkdir -p "$BUILD_DIR"
ln -fs -T "$BUILD_DIR" linux.build

cp ./linux-config "$BUILD_DIR"/.config
cd "$LINUX_DIR" || exit 1
make O="$BUILD_DIR" olddefconfig
cd "$BUILD_DIR" || exit 1
make -j
