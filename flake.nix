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
              archive = "roc_nightly-linux_x86_64-2026-08-31-86e69b4.tar.gz";
              hash = "sha256-6tnpYRU+SB+PhYiS7NUbYDfo6NPZha8/twRvTEL+Gkk=";
              directory = "roc_nightly-linux_x86_64-2026-08-31-86e69b4";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-31-86e69b4.tar.gz";
              hash = "sha256-stE2pFiB5wN+uEwrriS9DD7GxCZMg8JpY0K7a2ebnjU=";
              directory = "roc_nightly-linux_arm64-2026-08-31-86e69b4";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-31-86e69b4.tar.gz";
              hash = "sha256-BaKTZHt5Ph7jJVpSrnY3PtdJ+80Sg2zY60BEYdA6b+Q=";
              directory = "roc_nightly-macos_x86_64-2026-08-31-86e69b4";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-31-86e69b4.tar.gz";
              hash = "sha256-DLA0ptvpGzlT0bnjdJMMgjrK60Muxv+b0kyVdbz8rOQ=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-31-86e69b4";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-31-86e69b4";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-31-86e69b4/${nightly.archive}";
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
