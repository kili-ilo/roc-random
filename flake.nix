{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      perSystem =
        {
          pkgs,
          ...
        }:
        let
          nightly = {
            x86_64-linux = {
              archive = "roc_nightly-linux_x86_64-2026-08-30-34e7489.tar.gz";
              hash = "sha256-pNuXKgP2MN77N46MhiNWOTueXvwiFr6MHJdFlUnitBA=";
              directory = "roc_nightly-linux_x86_64-2026-08-30-34e7489";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-30-34e7489.tar.gz";
              hash = "sha256-jXC/26ym73VdKPtFEGCk3JYJ03FoAxujj4zqwE2Hmk4=";
              directory = "roc_nightly-linux_arm64-2026-08-30-34e7489";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-30-34e7489.tar.gz";
              hash = "sha256-UMAFvkx2FufJ4yOEmUcB2LAIs9YtwXgpfcE/Ktbj9bA=";
              directory = "roc_nightly-macos_x86_64-2026-08-30-34e7489";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-30-34e7489.tar.gz";
              hash = "sha256-nEII+mAaFxxSKXwndHE9ACj/VJvir1auOefyWJ5gM1w=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-30-34e7489";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-30-34e7489";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-30-34e7489/${nightly.archive}";
              inherit (nightly) hash;
            };
            dontBuild = true;
            unpackPhase = "tar -xzf $src";
            sourceRoot = ".";
            installPhase = ''
              mkdir -p $out/bin $out/lib
              install -m755 ${nightly.directory}/roc $out/bin/roc
              cp -R ${nightly.directory}/lib/. $out/lib/
            '';
          };
        in
        {
          devShells.default = pkgs.mkShell {
            name = "roc-random";
            packages = [
              roc-nightly
              pkgs.actionlint
              pkgs.nixfmt-rfc-style
              pkgs.nodePackages.prettier
            ];
          };
          formatter = pkgs.nixfmt-rfc-style;
        };
    };
}
