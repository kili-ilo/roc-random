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
              archive = "roc_nightly-linux_x86_64-2026-10-25-72704da.tar.gz";
              hash = "sha256-SbSLm4VvC4Coljj5V0+lBMmTNKMRCl9Cwj3V6c2uHns=";
              directory = "roc_nightly-linux_x86_64-2026-10-25-72704da";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-25-72704da.tar.gz";
              hash = "sha256-85vCITHi9yebBcN2Pq9+N0xEAlkTrP45iVHfzvfMWK0=";
              directory = "roc_nightly-linux_arm64-2026-10-25-72704da";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-25-72704da.tar.gz";
              hash = "sha256-SGDaejHcXFBMcDnaBzoXwKHmCk8KFZ07Y6X1MTaa+MI=";
              directory = "roc_nightly-macos_x86_64-2026-10-25-72704da";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-25-72704da.tar.gz";
              hash = "sha256-5aI3UtwzolceZy6hnK5pStiHb2g6Kw5dwwSrnROt0Os=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-25-72704da";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-25-72704da";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-25-72704da/${nightly.archive}";
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
