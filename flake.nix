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
              archive = "roc_nightly-linux_x86_64-2026-11-14-a87808d.tar.gz";
              hash = "sha256-qkx4RtrwakLTKkYK5giA8tiWh7KBIfx5ij1w6N751p8=";
              directory = "roc_nightly-linux_x86_64-2026-11-14-a87808d";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-11-14-a87808d.tar.gz";
              hash = "sha256-rDkVaqCiGPQRTgxZorXH79JlgmnvlR2PK42Dr80ZKCo=";
              directory = "roc_nightly-linux_arm64-2026-11-14-a87808d";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-11-14-a87808d.tar.gz";
              hash = "sha256-Wk+Uxh4eh8Qtg8JgA5UCBGyZd8F1KBTi7WRyUPkP3u0=";
              directory = "roc_nightly-macos_x86_64-2026-11-14-a87808d";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-11-14-a87808d.tar.gz";
              hash = "sha256-ytCVQ/USZqDz0MtYItCITmI2De+luy15OhN/DWm/kqg=";
              directory = "roc_nightly-macos_apple_silicon-2026-11-14-a87808d";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-11-14-a87808d";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-11-14-a87808d/${nightly.archive}";
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
