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
              archive = "roc_nightly-linux_x86_64-2026-08-12-606470f.tar.gz";
              hash = "sha256-+6w4OMzn6UaviQz6/kiZTJhTyZYt3mOy+YgNCky39+4=";
              directory = "roc_nightly-linux_x86_64-2026-08-12-606470f";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-12-606470f.tar.gz";
              hash = "sha256-Y9b0N8xhvyyisBYD6T25BXz2pkCt7+jT0zff6k4maEg=";
              directory = "roc_nightly-linux_arm64-2026-08-12-606470f";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-12-606470f.tar.gz";
              hash = "sha256-gcf0MtDX8wxt1G7RvcNhSXB11MvYBJZU4kSyh+r6nQk=";
              directory = "roc_nightly-macos_x86_64-2026-08-12-606470f";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-12-606470f.tar.gz";
              hash = "sha256-MOthF4SSC1NTW9S3rNgp/oX1Tyq6frDwTL8yeK0CFnk=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-12-606470f";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-12-606470f";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-12-606470f/${nightly.archive}";
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
