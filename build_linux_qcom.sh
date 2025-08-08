#!/usr/bin/env bash

DATE=$(date '+%y%m%d%H%M%S')
BUILD_DIR=$(realpath "linux-qcom.$DATE")
LINUX_QCOM_DIR="/local/mnt/workspace/amakarov/src/linux-qcom"

export ARCH="arm64"
# shellcheck disable=SC2154
export CROSS_COMPILE="$CROSS_COMPILE_arm64"

mkdir -p "$BUILD_DIR"
ln -fs -T "$BUILD_DIR" linux-qcom.build

cp $LINUX_QCOM_DIR/config "$BUILD_DIR"/.config
cd $LINUX_QCOM_DIR/linux || exit 1
make O="$BUILD_DIR" olddefconfig
cd "$BUILD_DIR" || exit 1
make -j
