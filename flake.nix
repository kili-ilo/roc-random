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
              archive = "roc_nightly-linux_x86_64-2026-10-11-7d256b9.tar.gz";
              hash = "sha256-zHai0NBuU1ligASpR/cl7XfplAEafd4UfScGhNjIBso=";
              directory = "roc_nightly-linux_x86_64-2026-10-11-7d256b9";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-11-7d256b9.tar.gz";
              hash = "sha256-jfcJ6BvvbsOGfwSb5HRudK3HEKz7boKXKheOeIjXtfs=";
              directory = "roc_nightly-linux_arm64-2026-10-11-7d256b9";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-11-7d256b9.tar.gz";
              hash = "sha256-F72qLcsqBUcoTQ1O7G3eFH2U5DmpJOymZHs7eU03h2o=";
              directory = "roc_nightly-macos_x86_64-2026-10-11-7d256b9";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-11-7d256b9.tar.gz";
              hash = "sha256-/ynpYlJDWHFGS/AVT/sowNQM/Z1BWGzSdV77Ss1YsZE=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-11-7d256b9";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-11-7d256b9";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-11-7d256b9/${nightly.archive}";
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
