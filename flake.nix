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
              archive = "roc_nightly-linux_x86_64-2026-11-18-a520eed.tar.gz";
              hash = "sha256-2TlUlfndB8OWKcM/FW9/7mjo0i+KdkUi5c3RzDCHm1E=";
              directory = "roc_nightly-linux_x86_64-2026-11-18-a520eed";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-11-18-a520eed.tar.gz";
              hash = "sha256-Fvsr1azozXjjSFQ2OYBk0svl4o08hOFVskYNMhAXIsM=";
              directory = "roc_nightly-linux_arm64-2026-11-18-a520eed";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-11-18-a520eed.tar.gz";
              hash = "sha256-r1m3YR1TuX4PldRgNd4ZLrYV5Yn13QbXBIcYvle1NYs=";
              directory = "roc_nightly-macos_x86_64-2026-11-18-a520eed";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-11-18-a520eed.tar.gz";
              hash = "sha256-O5ujzHNX5HkW8DaJl5vmw1wZhqH9WlS/DQbqYJ/gZI0=";
              directory = "roc_nightly-macos_apple_silicon-2026-11-18-a520eed";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-11-18-a520eed";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-11-18-a520eed/${nightly.archive}";
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
