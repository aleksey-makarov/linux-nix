#!/usr/bin/env bash

. ./build_linux.sh

LINUX_MIRROR_DIR="/home/amakarov/src/linux.git"

build_linux linux ${LINUX_MIRROR_DIR} v6.12.40 ./linux-config
