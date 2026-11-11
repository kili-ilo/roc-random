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
              archive = "roc_nightly-linux_x86_64-2026-11-11-7679cc5.tar.gz";
              hash = "sha256-RFPhnA2EyMBrndbSDv/qzYFR3mIZEz08udNhI1WpsYk=";
              directory = "roc_nightly-linux_x86_64-2026-11-11-7679cc5";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-11-11-7679cc5.tar.gz";
              hash = "sha256-EgZtWaouXfY4FbdK/DbYllCtFbCu5bKe7VEOKrL7aWo=";
              directory = "roc_nightly-linux_arm64-2026-11-11-7679cc5";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-11-11-7679cc5.tar.gz";
              hash = "sha256-HJNO5P8hxXTNaqNaBC3/ilMqu+OXADzxsiJ91LOt27c=";
              directory = "roc_nightly-macos_x86_64-2026-11-11-7679cc5";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-11-11-7679cc5.tar.gz";
              hash = "sha256-1U8axlfhAcNmSwXyoHDLOl3ayeD4ybhpKZXQqD4xMN8=";
              directory = "roc_nightly-macos_apple_silicon-2026-11-11-7679cc5";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-11-11-7679cc5";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-11-11-7679cc5/${nightly.archive}";
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
