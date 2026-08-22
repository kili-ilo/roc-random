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
              archive = "roc_nightly-linux_x86_64-2026-08-22-db56022.tar.gz";
              hash = "sha256-2P7zsjkBqQzqSE9dXAwJBr3y6yrR7EqDkSHF2vFqgKs=";
              directory = "roc_nightly-linux_x86_64-2026-08-22-db56022";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-22-db56022.tar.gz";
              hash = "sha256-27jIgtiCdzMkPuJZpBKWePkK9ByMNzYvWqnA2UxwihM=";
              directory = "roc_nightly-linux_arm64-2026-08-22-db56022";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-22-db56022.tar.gz";
              hash = "sha256-pwpe8P+rmvtohJM3ElQTJ0dNtNlyIpfrgFVLC43Wk3E=";
              directory = "roc_nightly-macos_x86_64-2026-08-22-db56022";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-22-db56022.tar.gz";
              hash = "sha256-/LwhEUsbQr/e4tnaPViSXw3DTSuW0XirDwkfpJ/n+3k=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-22-db56022";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-22-db56022";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-22-db56022/${nightly.archive}";
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
