{
  lib,
  writeShellScript,
  qemu,
  coreutils,
  e2fsprogs,
  util-linux,
  nixosSystem,
  init-binary,
  mesa,
  libglvnd,
}:

writeShellScript "run-qemu" ''
  set -euo pipefail

  KERNEL=$HOME/linux_build/arch/x86/boot/bzImage
  INIT_BINARY_NAME=$(${coreutils}/bin/basename ${init-binary})
  INIT_BINARY_MD5=$(${coreutils}/bin/md5sum ${init-binary} | ${coreutils}/bin/cut -d' ' -f1)
  DISK_IMAGE="$HOME/shimdisk-$INIT_BINARY_MD5.img"
  DISK_SIZE_BYTES=$((64 * 1024 * 1024))
  DISK_LABEL="imgroot"
  MODULES_DIR=$(${coreutils}/bin/realpath "''$HOME/linux_modules/lib/modules")
  QEMU_MEM_SIZE=8G

  export LD_LIBRARY_PATH="${mesa}/lib:${libglvnd}/lib"
  # : $ LD_LIBRARY_PATH"
  export LIBGL_DRIVERS_PATH="${mesa}/lib/dri"
  export LIBVA_DRIVERS_PATH="${mesa}/lib/dri"

  export VK_ICD_FILENAMES="${mesa}/share/vulkan/icd.d/radeon_icd.x86_64.json";

  # Create disk if it doesn't exist
  if [[ ! -f "$DISK_IMAGE" ]]; then
      echo "Creating disk image at $DISK_IMAGE..."

      # Create temporary directory for disk contents
      temp_dir=$(${coreutils}/bin/mktemp -d)
      trap "${coreutils}/bin/rm -rf $temp_dir" EXIT

      # Copy init-binary to disk root
      ${coreutils}/bin/cp ${init-binary} "$temp_dir/"

      # Create empty file of required size
      ${coreutils}/bin/truncate -s "$DISK_SIZE_BYTES" "$DISK_IMAGE"

      # Format as ext4 with contents
      ${e2fsprogs}/bin/mke2fs -t ext4 -F -U random -L "$DISK_LABEL" -E root_owner=0:0 -d "$temp_dir" "$DISK_IMAGE"

      # Remove trap and delete temporary directory manually
      trap - EXIT
      ${coreutils}/bin/rm -rf "$temp_dir"

      echo "Disk image created successfully"
    else
      echo "Disk image already exists at $DISK_IMAGE"
  fi

  # Create symbolic link for convenience
  SYMLINK_IMAGE="$HOME/shimdisk.img"
  ${coreutils}/bin/ln -sf "$DISK_IMAGE" "$SYMLINK_IMAGE"
  echo "Symlink created: $SYMLINK_IMAGE -> $DISK_IMAGE"

  # Create directory for file exchange
  ${coreutils}/bin/mkdir -p "$HOME/xchg"
  TTY_FILE="$HOME/xchg/tty.sh"
  read -r rows cols <<< "$(${coreutils}/bin/stty size)"

  cat << EOF > "''${TTY_FILE}"
  export TERM=xterm-256color
  stty rows ''$rows cols ''$cols
  reset
  EOF

  # Kernel parameters
  KERNEL_PARAMS=(
      "root=/dev/vda"
      "rootfstype=ext4"
      "rw"
      "init=/$INIT_BINARY_NAME"
      "console=ttyS0"
      "systemConfig=${nixosSystem}"
  )

  echo "Starting QEMU..."
  echo "Press Ctrl+] to exit QEMU"
  echo "----------------------------------------"

  ${coreutils}/bin/stty intr ^] # send INTR with Control-]

  ${qemu}/bin/qemu-system-x86_64 \
    -m $QEMU_MEM_SIZE \
    -cpu host -enable-kvm \
    -kernel "$KERNEL" \
    -drive file="$DISK_IMAGE",format=raw,if=virtio \
    -virtfs local,path=/nix/store,mount_tag=nixshare,security_model=passthrough,readonly=on \
    -virtfs local,path="$MODULES_DIR",mount_tag=modulesshare,security_model=passthrough,readonly=on \
    -append "''${KERNEL_PARAMS[*]}" \
    -device virtio-gpu-gl,hostmem=4G,blob=true,venus=true        \
    -display sdl,gl=on,show-cursor=on                            \
    -usb -device usb-tablet                                      \
    -object memory-backend-memfd,id=mem1,size=$QEMU_MEM_SIZE     \
    -machine memory-backend=mem1                                 \
    -serial stdio

  ${coreutils}/bin/stty intr ^c

  echo ""
  echo "QEMU exited"
''
