#!/usr/bin/env bash

. ./build_linux.sh

LINUX_MIRROR_DIR="/home/amakarov/src/linux.git"
LINUX_COMMIT=v6.12.40

prepare_linux_sources ${LINUX_MIRROR_DIR} ${LINUX_COMMIT}
build_linux linux linux.${LINUX_COMMIT} ./linux-config
