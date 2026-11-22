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
              archive = "roc_nightly-linux_x86_64-2026-11-22-3350b1c.tar.gz";
              hash = "sha256-TVqEOjREt14sLozTifkyR4HgJB9tgHMzm+hPa5GKHuw=";
              directory = "roc_nightly-linux_x86_64-2026-11-22-3350b1c";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-11-22-3350b1c.tar.gz";
              hash = "sha256-qOEIOpbFnWO41Jo5eXRvZwCeNrHEG/uhyAGKA8X/1Ek=";
              directory = "roc_nightly-linux_arm64-2026-11-22-3350b1c";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-11-22-3350b1c.tar.gz";
              hash = "sha256-t5VtUIZFojya4qVFRzZizJfNnmJWMGb6PiuI2KvJ8iU=";
              directory = "roc_nightly-macos_x86_64-2026-11-22-3350b1c";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-11-22-3350b1c.tar.gz";
              hash = "sha256-zS6C5A6946nhwccP7Oc7Bh7A+ZX996F9DdG0w53pXOg=";
              directory = "roc_nightly-macos_apple_silicon-2026-11-22-3350b1c";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-11-22-3350b1c";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-11-22-3350b1c/${nightly.archive}";
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
