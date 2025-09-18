{
  description = "Nix environment for linux kernel development";

  nixConfig.bash-prompt = "linux-nix";
  nixConfig.bash-prompt-prefix = "[\\[\\033[1;33m\\]";
  nixConfig.bash-prompt-suffix = "\\[\\033[0m\\] \\w]$ ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-vscode-extensions,
    }:
    let
      system = "x86_64-linux";

      overlays = [
        nix-vscode-extensions.overlays.default
        (final: prev: {
          shiminit = final.callPackage ./shiminit { };
          run-qemu = final.callPackage ./run-qemu.nix {
            nixosSystem = nixos.config.system.build.toplevel;
            init-binary = "${final.pkgsStatic.shiminit}/bin/shiminit";
          };
        })
      ];

      pkgs = import nixpkgs {
        inherit system overlays;
        config = {
          allowUnfree = true;
        };
      };

      pkgsARM = import nixpkgs {
        inherit overlays;
        system = "aarch64-linux";
      };

      pkgsCross = pkgs.pkgsCross.aarch64-multiplatform;

      nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration-test.nix
        ];
      };

      nixosARM = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./configuration-arm.nix
        ];
      };

      vscode = pkgs.vscode-with-extensions.override {
        vscodeExtensions = with pkgs; [

          vscode-marketplace.bbenoist.nix
          vscode-marketplace.timonwong.shellcheck
          vscode-marketplace-release.github.copilot
          vscode-marketplace-release.github.copilot-chat

        ];
      };

      run-qemu-aarch64 = with pkgs; writeShellScript "run-qemu-aarch64" ''
        set -euo pipefail

        # Kernel parameters
        KERNEL_PARAMS=(
            "root=/dev/vda"
            "rootfstype=ext4"
            "rw"
            # "init=/$INIT_BINARY_NAME"
            "console=ttyS0"
            "systemConfig=${nixosARM.config.system.build.toplevel}"
            "earlycon"
        )

        echo "Starting QEMU..."
        echo "Press Ctrl+] to exit QEMU"
        echo "----------------------------------------"

        ${coreutils}/bin/stty intr ^] # send INTR with Control-]
        ${qemu}/bin/qemu-system-aarch64 \
          -machine virt -smp 2 -cpu max -m 4G \
          -kernel ${nixosARM.config.boot.kernelPackages.kernel}/Image \
          -initrd ${nixosARM.config.system.build.initialRamdisk}/initrd \
          -append "''${KERNEL_PARAMS[*]}" \
          -display none \
          -serial stdio

          # -drive file="$DISK_IMAGE",format=raw,if=virtio \
          # -virtfs local,path=/nix/store,mount_tag=nixshare,security_model=passthrough,readonly=on \
          # -virtfs local,path="$MODULES_DIR",mount_tag=modulesshare,security_model=passthrough,readonly=on \
          # -cpu host -enable-kvm \

        ${coreutils}/bin/stty intr ^c

        echo ""
        echo "QEMU exited"
      '';

    in
    {
      devShells.${system} = rec {
        default =
          with pkgs;
          mkShell {
            packages = [
              vscode
              pkgsCross.stdenv.cc

              coreutils
              bc
              bison
              flex
              openssl
              perl
              cpio
              xz
              kmod
              ncurses
              python3
              git
              elfutils
              qemu

              nixfmt-rfc-style
              shellcheck

              mc # for mcedit
            ];
            shellHook = ''
              export HOME=$(pwd)
              echo "nixpkgs: ${nixpkgs}"
            '';
            env = {
              EDITOR = "mcedit";
              CROSS_COMPILE_arm64 = pkgsCross.stdenv.cc.targetPrefix;
              NIX_QEMU = pkgs.qemu;
            };
          };
      };

      packages.${system} = {
        u-boot = pkgs.pkgsCross.aarch64-multiplatform.ubootQemuAarch64;

        qemu = pkgs.qemu;
        run-qemu = pkgs.run-qemu;
        run-qemu-aarch64 = run-qemu-aarch64;

        shiminit = pkgs.pkgsStatic.shiminit;
        shiminit-arm = pkgsARM.pkgsStatic.shiminit;

        kernel = nixosARM.config.boot.kernelPackages.kernel;
        kernel-dev = nixosARM.config.boot.kernelPackages.kernel.dev;
        initramfs = nixosARM.config.system.build.initialRamdisk;
      };

      packages."aarch64-linux" = rec {
        # default = nixosARM.config.system.build.images.raw;
        iso = nixosARM.config.system.build.images.iso;
        default = nixosARM.config.system.build.images.sd-card;
      };

      applications.${system} = rec {
        test-script = {
          type = "app";
          program = "${pkgs.test-script}";
        };
      };
    };
}
