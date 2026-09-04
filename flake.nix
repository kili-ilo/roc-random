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
              archive = "roc_nightly-linux_x86_64-2026-09-04-c125b82.tar.gz";
              hash = "sha256-H6i1uEMsQrdRCyy8Ypwx6qo3UaIpUbdWrbNYDKuU/eM=";
              directory = "roc_nightly-linux_x86_64-2026-09-04-c125b82";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-09-04-c125b82.tar.gz";
              hash = "sha256-0iWoBLSGN4wAnJVd8Xk2qxld6zLUQfGV3PakyeE0CKI=";
              directory = "roc_nightly-linux_arm64-2026-09-04-c125b82";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-09-04-c125b82.tar.gz";
              hash = "sha256-6pk7tCnNL3DfcVDaWm3xwYrDyxMRQcoy4yuOueC4jqo=";
              directory = "roc_nightly-macos_x86_64-2026-09-04-c125b82";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-09-04-c125b82.tar.gz";
              hash = "sha256-w6oGSolYRQPBx0P8BFPk37Eu8S3AOaFvkVzrv2H3uRo=";
              directory = "roc_nightly-macos_apple_silicon-2026-09-04-c125b82";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-09-04-c125b82";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-09-04-c125b82/${nightly.archive}";
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
