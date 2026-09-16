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
              archive = "roc_nightly-linux_x86_64-2026-09-16-a49a16f.tar.gz";
              hash = "sha256-+iRCzv895mPBWN7gfMw3HocH9ZYaHBTKW7uQggQMHgA=";
              directory = "roc_nightly-linux_x86_64-2026-09-16-a49a16f";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-09-16-a49a16f.tar.gz";
              hash = "sha256-QgCzFDkA2HzX/xjryhqeiUcd4KJUXrfk9bZ2jH7zTvc=";
              directory = "roc_nightly-linux_arm64-2026-09-16-a49a16f";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-09-16-a49a16f.tar.gz";
              hash = "sha256-rccD7mdguB+05T0Mq/Gv4mU+KVbafP601VU/5JEhW5U=";
              directory = "roc_nightly-macos_x86_64-2026-09-16-a49a16f";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-09-16-a49a16f.tar.gz";
              hash = "sha256-1OntdJBQkJfzlwiqVUCkqIoeM12ncn8o2G7b5ZanpR0=";
              directory = "roc_nightly-macos_apple_silicon-2026-09-16-a49a16f";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-09-16-a49a16f";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-09-16-a49a16f/${nightly.archive}";
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
