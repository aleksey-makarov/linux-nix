#!/usr/bin/env bash

function prepare_linux_sources() {
	local source_git=$1
	local version=$2

	local LINUX_DIR
	LINUX_DIR=$(realpath "linux.$version")

	if [ ! -e "$LINUX_DIR" ] ; then
		echo "Creating $LINUX_DIR"
		git -c advice.detachedHead=false clone --depth=1 --branch "$version" --single-branch "file://$source_git" "$LINUX_DIR"
	else
		echo "$LINUX_DIR is already there"
	fi
}

function build_linux() {
	local name=$1
	local linux_source=$2
	local config=$3

	local LINUX_DIR DATE BUILD_DIR MODULES_DIR
	LINUX_DIR=$(realpath "$linux_source")
	DATE=$(date '+%y%m%d%H%M%S')
	BUILD_DIR=$(realpath "${name}_build.$DATE")
	MODULES_DIR=$(realpath "${name}_modules.$DATE")

	mkdir -p "$BUILD_DIR"
	ln -fs -T "$BUILD_DIR" "${name}_build"

	mkdir -p "$MODULES_DIR"
	ln -fs -T "$MODULES_DIR" "${name}_modules"

	cp "$config" "$BUILD_DIR"/.config
	cd "$LINUX_DIR" || exit 1
	make O="$BUILD_DIR" olddefconfig
	cd "$BUILD_DIR" || exit 1

	cat <<-EOF > go.sh
	#!/usr/bin/env bash

	make -j "\$(nproc)"
	INSTALL_MOD_PATH="$MODULES_DIR" make -j "\$(nproc)" modules_install
	EOF

	chmod +x go.sh
	# shellcheck source=/dev/null
	. ./go.sh
}
