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
              archive = "roc_nightly-linux_x86_64-2026-09-22-e494788.tar.gz";
              hash = "sha256-/n8UBGy2jRdsmfRqodF24hdD1zQcJT3hgVlESKX7X/M=";
              directory = "roc_nightly-linux_x86_64-2026-09-22-e494788";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-09-22-e494788.tar.gz";
              hash = "sha256-J39jZiCx5897rOLIf4/d2tJHSwhLf4dJ08PjQrKc+5M=";
              directory = "roc_nightly-linux_arm64-2026-09-22-e494788";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-09-22-e494788.tar.gz";
              hash = "sha256-y0bu13DHDS8xG4PXUtVEL++pHcGr+lXD6ARXaHz/FKI=";
              directory = "roc_nightly-macos_x86_64-2026-09-22-e494788";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-09-22-e494788.tar.gz";
              hash = "sha256-zyyt4MUSuHn86AZ3IeOdQCkprHXyUBqNIvl3bGL1kPg=";
              directory = "roc_nightly-macos_apple_silicon-2026-09-22-e494788";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-09-22-e494788";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-09-22-e494788/${nightly.archive}";
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
