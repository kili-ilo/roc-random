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
              archive = "roc_nightly-linux_x86_64-2026-11-09-9e85de7.tar.gz";
              hash = "sha256-nSSA6QC+4nyuCXQmbAiPQ+jizqplQ8K+cxS3vdK3iR0=";
              directory = "roc_nightly-linux_x86_64-2026-11-09-9e85de7";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-11-09-9e85de7.tar.gz";
              hash = "sha256-nBLYWrzoqjba7Z/+BMdf4AxnsPyTlkeJlJNQCho7Xv8=";
              directory = "roc_nightly-linux_arm64-2026-11-09-9e85de7";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-11-09-9e85de7.tar.gz";
              hash = "sha256-G/3jxgAJEBU8BiiXkUWJw13G6XZ/OiP39+I80CZPWPU=";
              directory = "roc_nightly-macos_x86_64-2026-11-09-9e85de7";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-11-09-9e85de7.tar.gz";
              hash = "sha256-DhLhXBwdCvgXwfJ7DxA6ZQLCs66lh/HefX3zEmQtdNM=";
              directory = "roc_nightly-macos_apple_silicon-2026-11-09-9e85de7";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-11-09-9e85de7";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-11-09-9e85de7/${nightly.archive}";
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
