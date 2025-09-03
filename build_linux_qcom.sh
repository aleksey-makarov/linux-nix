#!/usr/bin/env bash

. ./build_linux.sh

LINUX_QCOM_DIR="/local/mnt/workspace/amakarov/src/linux-qcom"

export ARCH="arm64"
# shellcheck disable=SC2154
export CROSS_COMPILE="$CROSS_COMPILE_arm64"

build_linux linux_qcom $LINUX_QCOM_DIR/linux $LINUX_QCOM_DIR/config
