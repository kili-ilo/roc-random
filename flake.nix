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
              archive = "roc_nightly-linux_x86_64-2026-09-19-d025939.tar.gz";
              hash = "sha256-yo2KodhzjyeyyPMD398DQ9ij9ny+PYS0AvaHxkIcJfI=";
              directory = "roc_nightly-linux_x86_64-2026-09-19-d025939";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-09-19-d025939.tar.gz";
              hash = "sha256-d5HIgsN7q7Unh16XB0VY3KnqdABQaubNku6R3nUgMiM=";
              directory = "roc_nightly-linux_arm64-2026-09-19-d025939";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-09-19-d025939.tar.gz";
              hash = "sha256-UIJcUibUx1O+UuAaPZTFt8k+LGGmTQ/43zTN4MHkhaY=";
              directory = "roc_nightly-macos_x86_64-2026-09-19-d025939";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-09-19-d025939.tar.gz";
              hash = "sha256-NmuBgOedQ2fV3wsUYiTq/meP5EIPBUfUXrEfOL8mwNA=";
              directory = "roc_nightly-macos_apple_silicon-2026-09-19-d025939";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-09-19-d025939";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-09-19-d025939/${nightly.archive}";
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
