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
              archive = "roc_nightly-linux_x86_64-2026-10-03-c507926.tar.gz";
              hash = "sha256-/g4aqfAcckzKLVZDdO6yBciOLSjIAEX1aO++H0s+DnQ=";
              directory = "roc_nightly-linux_x86_64-2026-10-03-c507926";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-03-c507926.tar.gz";
              hash = "sha256-4mNxysfP8hu2NTqMJ4D97PM/8n6mLBA8nwGqFIGgspI=";
              directory = "roc_nightly-linux_arm64-2026-10-03-c507926";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-03-c507926.tar.gz";
              hash = "sha256-Ce+vUHrNtmnem7AyVaDgEuKKYWiuQUrMvys5Z/WO1HQ=";
              directory = "roc_nightly-macos_x86_64-2026-10-03-c507926";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-03-c507926.tar.gz";
              hash = "sha256-iQ3FoxKdCvbeIaiENBBBkLcavML5+hetsjeNyfuA6mM=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-03-c507926";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-03-c507926";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-03-c507926/${nightly.archive}";
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
