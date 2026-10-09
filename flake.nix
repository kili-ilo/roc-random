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
              archive = "roc_nightly-linux_x86_64-2026-10-09-258ab27.tar.gz";
              hash = "sha256-3LmavfF9BiJGwF45Q1etaCuIOmvP97LlgeIFZOqI/8Q=";
              directory = "roc_nightly-linux_x86_64-2026-10-09-258ab27";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-09-258ab27.tar.gz";
              hash = "sha256-l1DOiagg083q3XUZltJscLaFhMqUKOUvQ6G7IHAsVOU=";
              directory = "roc_nightly-linux_arm64-2026-10-09-258ab27";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-09-258ab27.tar.gz";
              hash = "sha256-rATHSUbhTL+Hi2NEtufHmup0Hwho4D84DuMH22JQd3Y=";
              directory = "roc_nightly-macos_x86_64-2026-10-09-258ab27";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-09-258ab27.tar.gz";
              hash = "sha256-qmM5V5cw/OpHU5QL7CH12M+L6OJWWewAGrzLw0Y6YLI=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-09-258ab27";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-09-258ab27";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-09-258ab27/${nightly.archive}";
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
