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
              archive = "roc_nightly-linux_x86_64-2026-08-25-cc03aa8.tar.gz";
              hash = "sha256-Ck7PM9GGh4C4vfUjDthVOvHGl/buHPrusJWIUj35sKQ=";
              directory = "roc_nightly-linux_x86_64-2026-08-25-cc03aa8";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-25-cc03aa8.tar.gz";
              hash = "sha256-AHFU/zlekdNRyHHxRUac0aANDHEe4vG3cx0rdeKbETg=";
              directory = "roc_nightly-linux_arm64-2026-08-25-cc03aa8";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-25-cc03aa8.tar.gz";
              hash = "sha256-MWWRVZWe3VcjFnd2aDVLgv92nT+PWRGO+ww478qjRDc=";
              directory = "roc_nightly-macos_x86_64-2026-08-25-cc03aa8";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-25-cc03aa8.tar.gz";
              hash = "sha256-5lPI58ZppVzW6AU8tZKqAKCNFmakV01PCJ0fijmnU7w=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-25-cc03aa8";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-25-cc03aa8";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-25-cc03aa8/${nightly.archive}";
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
