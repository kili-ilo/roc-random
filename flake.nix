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
              archive = "roc_nightly-linux_x86_64-2026-08-29-2d69988.tar.gz";
              hash = "sha256-vmv2IJdZQjjyBb/G42kFC3Ymmf+F4FrV3FBf1WQyk6s=";
              directory = "roc_nightly-linux_x86_64-2026-08-29-2d69988";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-29-2d69988.tar.gz";
              hash = "sha256-2tBSUYKxEXLDr1gUXd5a0ZX0Qz3nGm+gUFW35HYKa40=";
              directory = "roc_nightly-linux_arm64-2026-08-29-2d69988";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-29-2d69988.tar.gz";
              hash = "sha256-c70gG7wAhG/yHRv3ERx8NRWygWChuTwhxoeqbZFFOjM=";
              directory = "roc_nightly-macos_x86_64-2026-08-29-2d69988";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-29-2d69988.tar.gz";
              hash = "sha256-VfMx3W/0rnRf8pFiLcReookBSL4eTXGnqpVo9aDNNAw=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-29-2d69988";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-29-2d69988";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-29-2d69988/${nightly.archive}";
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
