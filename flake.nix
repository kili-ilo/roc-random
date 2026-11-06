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
              archive = "roc_nightly-linux_x86_64-2026-11-06-34f137a.tar.gz";
              hash = "sha256-02JW15CxQadlmeiqQQIMwCLBBJ9hnPs5rbMrwpSMZB4=";
              directory = "roc_nightly-linux_x86_64-2026-11-06-34f137a";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-11-06-34f137a.tar.gz";
              hash = "sha256-1TPTatwYFEh8ZuDHX9JqKlUc55k9afAuKQbjsR8swbA=";
              directory = "roc_nightly-linux_arm64-2026-11-06-34f137a";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-11-06-34f137a.tar.gz";
              hash = "sha256-loqodvScxuwjEAo3/cMDA6rfDyqeVJL43eJk18erD6w=";
              directory = "roc_nightly-macos_x86_64-2026-11-06-34f137a";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-11-06-34f137a.tar.gz";
              hash = "sha256-NTppxEiz5Ga9i9SwBnbtfbe59oljDWsAedsBL1t681c=";
              directory = "roc_nightly-macos_apple_silicon-2026-11-06-34f137a";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-11-06-34f137a";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-11-06-34f137a/${nightly.archive}";
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
