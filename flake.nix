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
      systemARM = "aarch64-linux";

      overlays = [
        nix-vscode-extensions.overlays.default
      ];

      pkgs = import nixpkgs {
        inherit system overlays;
        config = {
          allowUnfree = true;
        };
      };

      pkgsARM = import nixpkgs { system = systemARM; };
      pkgsCross = pkgs.pkgsCross.aarch64-multiplatform;

      nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          ./qemu-vm-no-kernel.nix
        ];
      };

      nixosARM = nixpkgs.lib.nixosSystem {
        system = systemARM;
        modules = [
          ./configuration.nix
          # ./qemu-vm-no-kernel.nix
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

      startvm_sh = pkgs.writeShellScript "startvm.sh" ''
        ${pkgs.coreutils}/bin/mkdir -p ./xchg

        TMPDIR=''$(pwd)
        USE_TMPDIR=1
        export TMPDIR USE_TMPDIR

        TTY_FILE="./xchg/tty.sh"
        read -r rows cols <<< "''$(${pkgs.coreutils}/bin/stty size)"

        cat << EOF > "''${TTY_FILE}"
        export TERM=xterm-256color
        stty rows ''$rows cols ''$cols
        reset
        EOF

        ${pkgs.coreutils}/bin/stty intr ^] # send INTR with Control-]
        ${pkgs.qemu}/bin/qemu-system-aarch64 -nographic \
            -machine virt -cpu cortex-a57 \
            -bios ${pkgs.qemu}/share/qemu/edk2-aarch64-code.fd \
            -drive if=none,file=./nixos-image-sd-card-aarch64-linux.img,id=hd0,format=raw \
            -device virtio-blk-device,drive=hd0 \
            -m 4G

            # -bios ${pkgs.pkgsCross.aarch64-multiplatform.ubootQemuAarch64}/u-boot.bin \
            # -dtb ${pkgs.qemu}/share/qemu/edk2-aarch64-code.dtb \
            # ./nixos-image-sd-card-aarch64-linux.img \

        ${pkgs.coreutils}/bin/stty intr ^c
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
            };
          };
      };

      packages.${system} = rec {
        u-boot = pkgs.pkgsCross.aarch64-multiplatform.ubootQemuAarch64;
        qemu = pkgs.qemu;
        startvm = startvm_sh;
        # default = nixos.config.system.build.images.raw;
        iso = nixos.config.system.build.images.iso;
        sd-card = nixos.config.system.build.images.sd-card;
        kernel = nixos.config.boot.kernelPackages.kernel;
        kernel-dev = nixos.config.boot.kernelPackages.kernel.dev;
        initramfs = nixos.config.system.build.initialRamdisk;
        default = nixos.config.system.build.vm;
      };

      packages.${systemARM} = rec {
        # default = nixosARM.config.system.build.images.raw;
        iso = nixosARM.config.system.build.images.iso;
        default = nixosARM.config.system.build.images.sd-card;
      };

      applications.${system} = rec {

        startvm = {
          type = "app";
          program = "${startvm_sh}";
        };

        nixos = {
          type = "app";
          program = "${nixos.config.system.build.vm}/bin/run-nixos-vm";
        };

        default = nixos;
      };

    };
}
