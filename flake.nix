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
              archive = "roc_nightly-linux_x86_64-2026-08-20-9e3980a.tar.gz";
              hash = "sha256-yxzDyCyHzHsnT6mIuzAEFodfngpMZ1QHSWxqnlm7a50=";
              directory = "roc_nightly-linux_x86_64-2026-08-20-9e3980a";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-20-9e3980a.tar.gz";
              hash = "sha256-MmezAI9tN/EiSz04BoGZkE/7lJH0BDIqbPgiNJO5HlM=";
              directory = "roc_nightly-linux_arm64-2026-08-20-9e3980a";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-20-9e3980a.tar.gz";
              hash = "sha256-S9K6Bd7OrOqW3kvxGpE0KsSOgyuccvMMlhZBdyJw2Sg=";
              directory = "roc_nightly-macos_x86_64-2026-08-20-9e3980a";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-20-9e3980a.tar.gz";
              hash = "sha256-LvqizI0tLHzLMZCPZV2MMlxoV1vIjKRlkxTKoA11TOk=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-20-9e3980a";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-20-9e3980a";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-20-9e3980a/${nightly.archive}";
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
