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
              archive = "roc_nightly-linux_x86_64-2026-10-30-0602c5f.tar.gz";
              hash = "sha256-5nJWrqxO7dmVaIAuwYfRVeVFlOQPtHX3tzAFx0QQxwg=";
              directory = "roc_nightly-linux_x86_64-2026-10-30-0602c5f";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-30-0602c5f.tar.gz";
              hash = "sha256-XUOFyZ3ERjrhpfNVkSlWBAEI/OQ5fCSvs/piOQ10bak=";
              directory = "roc_nightly-linux_arm64-2026-10-30-0602c5f";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-30-0602c5f.tar.gz";
              hash = "sha256-jN0KrDSExsaiUA52i80ZvmJLnwu+uv9qsRfr/0heorM=";
              directory = "roc_nightly-macos_x86_64-2026-10-30-0602c5f";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-30-0602c5f.tar.gz";
              hash = "sha256-rTSV84smEUbBh+yoeInjiBJgVX3hTUgzZ4MfDuVCvMk=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-30-0602c5f";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-30-0602c5f";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-30-0602c5f/${nightly.archive}";
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
