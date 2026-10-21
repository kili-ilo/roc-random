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
              archive = "roc_nightly-linux_x86_64-2026-10-21-5349569.tar.gz";
              hash = "sha256-cDRqxg3QsFB4gUR8W0eu15n9G+oBxQusVvgu2WiX9N8=";
              directory = "roc_nightly-linux_x86_64-2026-10-21-5349569";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-21-5349569.tar.gz";
              hash = "sha256-y2y+guRbooTVsBkQ6Okal4cB/+08K68smoi6pK3DafU=";
              directory = "roc_nightly-linux_arm64-2026-10-21-5349569";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-21-5349569.tar.gz";
              hash = "sha256-MbHBX1YnpxROZsJmlb0/0RwdrC9hnCVjmPkTTHzJvsY=";
              directory = "roc_nightly-macos_x86_64-2026-10-21-5349569";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-21-5349569.tar.gz";
              hash = "sha256-qKgbVDbGnrW/FN3Ei9nw73Eyb9SFNApKGnpoPbRC5aY=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-21-5349569";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-21-5349569";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-21-5349569/${nightly.archive}";
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
