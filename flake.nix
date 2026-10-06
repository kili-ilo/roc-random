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
              archive = "roc_nightly-linux_x86_64-2026-10-06-c34079d.tar.gz";
              hash = "sha256-Eb9cc7geUXrigH9CEf6emW9I+HposehbgsSuLGSZpdY=";
              directory = "roc_nightly-linux_x86_64-2026-10-06-c34079d";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-06-c34079d.tar.gz";
              hash = "sha256-Hv3IxNu4E8/xAlShPXWCIWKn3ejPyTr6k8LCtUXOAtQ=";
              directory = "roc_nightly-linux_arm64-2026-10-06-c34079d";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-06-c34079d.tar.gz";
              hash = "sha256-egS6t2Mo6QNj//4XTCdd68jJ2WTylArHTt1IR40MYik=";
              directory = "roc_nightly-macos_x86_64-2026-10-06-c34079d";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-06-c34079d.tar.gz";
              hash = "sha256-eO8/wlFh2QgyHS2uK5BTvAOh6Ub4Uo14rsWUwvQBpe0=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-06-c34079d";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-06-c34079d";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-06-c34079d/${nightly.archive}";
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
