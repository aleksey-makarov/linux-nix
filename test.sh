#!/usr/bin/env bash

set -euo pipefail

QROOT=$HOME/qroot
KERNEL=$HOME/linux_build/arch/x86/boot/bzImage
ROOT_9P_TAG="rootshare"

SYS=$(nix build '.#nixosConfigurations.qemu.config.system.build.toplevel' --no-link --print-out-paths --extra-experimental-features nix-command --extra-experimental-features flakes)

if [[ ! -d "$QROOT" ]]; then
    echo "Error: Directory $QROOT does not exist" >&2
    exit 1
fi

if [[ ! -d "$QROOT/nix" ]]; then
    echo "Error: Directory $QROOT/nix does not exist" >&2
    exit 1
fi

# Параметры ядра
KERNEL_PARAMS=(
    "root=$ROOT_9P_TAG"
    "rootfstype=9p"
    "rootflags=trans=virtio,version=9p2000.L"
    "rw"
    "init=$SYS/init"
    "console=ttyS0"
    "systemConfig=$SYS"
)

set -x
qemu-system-x86_64 \
  -m 2048 \
  -cpu host -enable-kvm \
  -kernel "$KERNEL" \
  -fsdev local,id=rootfs,path="$QROOT",security_model=none \
  -device virtio-9p-pci,fsdev=rootfs,mount_tag=$ROOT_9P_TAG \
  -append "${KERNEL_PARAMS[*]}" \
  -nographic
