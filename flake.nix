{
  description = "QEMU AArch64";

  nixConfig.bash-prompt = "qemu-aarch64";
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
      ];

      pkgs = import nixpkgs {
        inherit system overlays;
        config = {
          allowUnfree = true;
        };
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
        env =
          with pkgs;
          mkShell {
            packages = [
              vscode
              nixfmt-rfc-style
            ];
            shellHook = ''
              echo "nixpkgs: ${nixpkgs}"
              export HOME=$(pwd)
            '';
          };
        default = env;
      };
    };
}
