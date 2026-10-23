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
              archive = "roc_nightly-linux_x86_64-2026-10-23-18478ff.tar.gz";
              hash = "sha256-woOuAedYudZAAtcrjkrXdkZufm5fSV/UZuJ0r70lzn8=";
              directory = "roc_nightly-linux_x86_64-2026-10-23-18478ff";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-23-18478ff.tar.gz";
              hash = "sha256-bbqCAJaHR1cKiyYIeqB+GIBDOy53bruQG/9YEu6BT60=";
              directory = "roc_nightly-linux_arm64-2026-10-23-18478ff";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-23-18478ff.tar.gz";
              hash = "sha256-3lVdscjtua1/JEkpAVGJCA3SBcfhipP8n6hehSUMxP4=";
              directory = "roc_nightly-macos_x86_64-2026-10-23-18478ff";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-23-18478ff.tar.gz";
              hash = "sha256-ZosnMcYqyQVOz1zU1INjjCN2JlF99sB2IEhwBloQOzg=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-23-18478ff";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-23-18478ff";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-23-18478ff/${nightly.archive}";
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
