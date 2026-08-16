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
              archive = "roc_nightly-linux_x86_64-2026-08-16-23452ea.tar.gz";
              hash = "sha256-5jr2Fd0SGqTdtW3Qy5FOQdVsnYWO6OzUCpYTXXnOuMY=";
              directory = "roc_nightly-linux_x86_64-2026-08-16-23452ea";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-16-23452ea.tar.gz";
              hash = "sha256-RT4LYq94O+MsIeLyZH7eeGZWm+kW3DTMNuhUO/As1VU=";
              directory = "roc_nightly-linux_arm64-2026-08-16-23452ea";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-16-23452ea.tar.gz";
              hash = "sha256-Yxbf6aoyd0SQ1f00q0aQpHyuX9LxxvNVLQ6vpI5LxMw=";
              directory = "roc_nightly-macos_x86_64-2026-08-16-23452ea";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-16-23452ea.tar.gz";
              hash = "sha256-oJNP+5BkGaBhL4AKhMUDnUmNKo1MiUGFMWayW4MGJVU=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-16-23452ea";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-16-23452ea";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-16-23452ea/${nightly.archive}";
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
