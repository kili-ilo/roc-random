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
              archive = "roc_nightly-linux_x86_64-2026-09-02-d2609e2.tar.gz";
              hash = "sha256-wkpohY5klsvwjg9CIGH14tJ/0VH4wVbxo18DSsNQbwc=";
              directory = "roc_nightly-linux_x86_64-2026-09-02-d2609e2";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-09-02-d2609e2.tar.gz";
              hash = "sha256-ox1UIoZ0jRUR1rkxVm0zExAIDEhi+15MK3I5XvkRP1o=";
              directory = "roc_nightly-linux_arm64-2026-09-02-d2609e2";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-09-02-d2609e2.tar.gz";
              hash = "sha256-hezy03pGcZd9k/q77f1V78fgcteVUizBGc3Q062qOTo=";
              directory = "roc_nightly-macos_x86_64-2026-09-02-d2609e2";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-09-02-d2609e2.tar.gz";
              hash = "sha256-t3gfJTsRFrwKhhf5g9IU867upE6dZGzDI65UFyCzxZo=";
              directory = "roc_nightly-macos_apple_silicon-2026-09-02-d2609e2";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-09-02-d2609e2";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-09-02-d2609e2/${nightly.archive}";
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
