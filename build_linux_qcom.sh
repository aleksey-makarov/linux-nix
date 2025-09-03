#!/usr/bin/env bash

. ./build_linux.sh

LINUX_QCOM_DIR="/local/mnt/workspace/amakarov/src/linux-qcom"

if [ -z "$CROSS_COMPILE_arm64" ]; then
	echo "environment variable CROSS_COMPILE_arm64 should be set"
	exit 1
fi

export ARCH=arm64
export CROSS_COMPILE=$CROSS_COMPILE_arm64

build_linux linux_qcom $LINUX_QCOM_DIR/linux $LINUX_QCOM_DIR/config
