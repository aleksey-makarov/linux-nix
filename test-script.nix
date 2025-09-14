{ lib
, writeShellScript
, qemu
, coreutils
, e2fsprogs
, util-linux
, nixosSystem
, init-binary
}:

writeShellScript "test-qemu" ''
  set -euo pipefail

  KERNEL=$HOME/linux_build/arch/x86/boot/bzImage
  INIT_BINARY_NAME=$(${coreutils}/bin/basename ${init-binary})
  INIT_BINARY_MD5=$(${coreutils}/bin/md5sum ${init-binary} | ${coreutils}/bin/cut -d' ' -f1)
  DISK_IMAGE="$HOME/shimdisk-$INIT_BINARY_MD5.img"
  DISK_SIZE_BYTES=$((64 * 1024 * 1024))
  DISK_LABEL="imgroot"

  # Создаем диск если его нет
  if [[ ! -f "$DISK_IMAGE" ]]; then
      echo "Creating disk image at $DISK_IMAGE..."

      # Создаем временную директорию для содержимого диска
      temp_dir=$(${coreutils}/bin/mktemp -d)
      trap "${coreutils}/bin/rm -rf $temp_dir" EXIT

      # Копируем init-binary в корень диска
      ${coreutils}/bin/cp ${init-binary} "$temp_dir/"

      # Создаем пустой файл нужного размера
      ${coreutils}/bin/truncate -s "$DISK_SIZE_BYTES" "$DISK_IMAGE"

      # Форматируем как ext4 с содержимым
      ${e2fsprogs}/bin/mke2fs -t ext4 -F -U random -L "$DISK_LABEL" -E root_owner=0:0 -d "$temp_dir" "$DISK_IMAGE"

      # Убираем trap и удаляем временную директорию вручную
      trap - EXIT
      ${coreutils}/bin/rm -rf "$temp_dir"

      echo "Disk image created successfully"
    else
      echo "Disk image already exists at $DISK_IMAGE"
  fi

  # Параметры ядра
  KERNEL_PARAMS=(
      "root=/dev/vda"
      "rootfstype=ext4"
      "rw"
      "init=/$INIT_BINARY_NAME"
      "console=ttyS0"
      "systemConfig=${nixosSystem}"
  )

  echo "Starting QEMU..."
  echo "Press Ctrl+C to exit QEMU"
  echo "----------------------------------------"

  ${qemu}/bin/qemu-system-x86_64 \
    -m 2048 \
    -cpu host -enable-kvm \
    -kernel "$KERNEL" \
    -drive file="$DISK_IMAGE",format=raw,if=virtio \
    -append "''${KERNEL_PARAMS[*]}" \
    -display none \
    -serial stdio

  echo ""
  echo "QEMU exited"
''
