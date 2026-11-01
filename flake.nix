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
              archive = "roc_nightly-linux_x86_64-2026-11-01-48d3369.tar.gz";
              hash = "sha256-EQreVAh8q8MQK7G0p0kxL6AUIuRC8ySbaV1xMzR9cMU=";
              directory = "roc_nightly-linux_x86_64-2026-11-01-48d3369";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-11-01-48d3369.tar.gz";
              hash = "sha256-fQJ5rqtHX+bCW/ZTFU2jFb/mPlgLgtagwnFZKUjQ/b4=";
              directory = "roc_nightly-linux_arm64-2026-11-01-48d3369";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-11-01-48d3369.tar.gz";
              hash = "sha256-mWgaCS1Q5zi19PYCaeyvAEgsL3Upyu1V1NLiYUb9tEA=";
              directory = "roc_nightly-macos_x86_64-2026-11-01-48d3369";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-11-01-48d3369.tar.gz";
              hash = "sha256-zC6IsF4TC9J9Yd9tY/MjUbQtcPtBs50QPusUilbToW8=";
              directory = "roc_nightly-macos_apple_silicon-2026-11-01-48d3369";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-11-01-48d3369";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-11-01-48d3369/${nightly.archive}";
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
