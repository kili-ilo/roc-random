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
              archive = "roc_nightly-linux_x86_64-2026-09-03-62fcb65.tar.gz";
              hash = "sha256-rQVgDeNZRIk7t3WYokffO+8MR3g0xgzUm6NlpdDZhx4=";
              directory = "roc_nightly-linux_x86_64-2026-09-03-62fcb65";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-09-03-62fcb65.tar.gz";
              hash = "sha256-6Kkrwgb3TWeMJ177VBcT9urUx9HzXdUogQsdM/nKtw8=";
              directory = "roc_nightly-linux_arm64-2026-09-03-62fcb65";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-09-03-62fcb65.tar.gz";
              hash = "sha256-muWHOfM/VVj9HA/O2AvVUC98t5sCwJSuMCE5wIBWtSE=";
              directory = "roc_nightly-macos_x86_64-2026-09-03-62fcb65";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-09-03-62fcb65.tar.gz";
              hash = "sha256-oA/GCNsx9VSubamQQfg6MNbiE6Eab/7se+H7u3B9yAs=";
              directory = "roc_nightly-macos_apple_silicon-2026-09-03-62fcb65";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-09-03-62fcb65";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-09-03-62fcb65/${nightly.archive}";
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
