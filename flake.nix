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
              archive = "roc_nightly-linux_x86_64-2026-08-27-8fa1a34.tar.gz";
              hash = "sha256-z/sXvPRFbmgkKeM82LsmLdUAUFXXzhKg8hLKergfdY0=";
              directory = "roc_nightly-linux_x86_64-2026-08-27-8fa1a34";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-27-8fa1a34.tar.gz";
              hash = "sha256-E63NdVItjnBcXKpNDl305xMifEMv8chQw5MRhSPJ6Yc=";
              directory = "roc_nightly-linux_arm64-2026-08-27-8fa1a34";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-27-8fa1a34.tar.gz";
              hash = "sha256-SFNcxHtVN3/bFXAuPoGSGxd3JD4oMKLmTkfDDaNgWpc=";
              directory = "roc_nightly-macos_x86_64-2026-08-27-8fa1a34";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-27-8fa1a34.tar.gz";
              hash = "sha256-kjWuT2dBen8OxRSs0RJYs2zwKdwpIqYX9BCmvLguQpI=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-27-8fa1a34";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-27-8fa1a34";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-27-8fa1a34/${nightly.archive}";
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
