init-binary:

{
  lib,
  e2fsprogs,
  util-linux,
  runCommand,

  sizeBytes ? 64 * 1024 * 1024,
  label ? "imgroot",
}:

runCommand "shimdisk"
  {

    buildInputs = [
      e2fsprogs
      util-linux
    ];

    meta = with lib; {
      description = "Simple init disk image";
      platforms = platforms.linux;
    };

    preferLocalBuild = true;
    allowSubstitutes = false;
  }
  ''
    set -euo pipefail

    mkdir -p $out
    img_raw="$out/img.raw"

    root_dir="$PWD/shimdisk"
    mkdir -p "$root_dir"

    cp ${init-binary} "$root_dir"

    truncate -s "${toString sizeBytes}" "$img_raw"

    mke2fs -t ext4 -F -U random -L "${label}" -E root_owner=0:0 -d "$root_dir" "$img_raw"

    mkdir -p $out/nix-support
    echo "file disk-image $img_raw" >> $out/nix-support/hydra-build-products
  ''
