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
              NIX_QEMU = pkgs.qemu;
            };
          };
      };

      packages.${system} = rec {
        u-boot = pkgs.pkgsCross.aarch64-multiplatform.ubootQemuAarch64;

        qemu = pkgs.qemu;
        run-qemu= pkgs.run-qemu;

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
