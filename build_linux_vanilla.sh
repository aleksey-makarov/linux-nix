#!/usr/bin/env bash

. ./build_linux.sh

case $(uname -n) in
	potato)
		LINUX_MIRROR_DIR="/home/amakarov/src/linux.git"
		;;
	*)
		LINUX_MIRROR_DIR="/local/mnt/workspace/amakarov/src/linux.git"
		;;
esac

build_linux linux ${LINUX_MIRROR_DIR} v6.12.40 ./linux-config
