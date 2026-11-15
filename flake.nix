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
              archive = "roc_nightly-linux_x86_64-2026-11-15-f25da45.tar.gz";
              hash = "sha256-mGNgNIprv08naW9rPXPwJgKTgTNGcSo/cuc2RSZx6ZQ=";
              directory = "roc_nightly-linux_x86_64-2026-11-15-f25da45";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-11-15-f25da45.tar.gz";
              hash = "sha256-38l8bd+JfXcXy5WhngwKmNHUr65PJZ5pH4lZhw83kXY=";
              directory = "roc_nightly-linux_arm64-2026-11-15-f25da45";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-11-15-f25da45.tar.gz";
              hash = "sha256-gEUQ9f0lImHCFj0uYQXGmhkggHXTWSbuIrWeBPnACvs=";
              directory = "roc_nightly-macos_x86_64-2026-11-15-f25da45";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-11-15-f25da45.tar.gz";
              hash = "sha256-O73E1McMNEb25ZUEx/DhIsrh3ifW+UvnTEHtchj+CJY=";
              directory = "roc_nightly-macos_apple_silicon-2026-11-15-f25da45";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-11-15-f25da45";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-11-15-f25da45/${nightly.archive}";
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
