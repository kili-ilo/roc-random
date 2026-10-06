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
              archive = "roc_nightly-linux_x86_64-2026-10-04-130536d.tar.gz";
              hash = "sha256-iTyG0toKTDkMvb1CWM5F1obl7BW0Lu64Ef0axEU3cU8=";
              directory = "roc_nightly-linux_x86_64-2026-10-04-130536d";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-04-130536d.tar.gz";
              hash = "sha256-9FMtKQyDkg0j8ZHaRlCxmqgwJ0PtNcq06a3IO+rwwds=";
              directory = "roc_nightly-linux_arm64-2026-10-04-130536d";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-04-130536d.tar.gz";
              hash = "sha256-zY3wdyzB2DGs6p6+AANA0kQpfjc5Pk0Ki1gfgwBCL9Q=";
              directory = "roc_nightly-macos_x86_64-2026-10-04-130536d";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-04-130536d.tar.gz";
              hash = "sha256-4BR/YvByowlRnLwqbr+hHku4useQPV/rr3oRLR/ChC8=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-04-130536d";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-04-130536d";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-04-130536d/${nightly.archive}";
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
