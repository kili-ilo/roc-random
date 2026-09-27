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
              archive = "roc_nightly-linux_x86_64-2026-09-27-a3ce7f1.tar.gz";
              hash = "sha256-DI2xJU6ZbM2BmHG+u2Y1EeU7KoyB+QoJbNKEHxJnKac=";
              directory = "roc_nightly-linux_x86_64-2026-09-27-a3ce7f1";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-09-27-a3ce7f1.tar.gz";
              hash = "sha256-+8mZW1MWV2RpsRiIjYxUU0Y2yaeLZr2S1s11x5eitAc=";
              directory = "roc_nightly-linux_arm64-2026-09-27-a3ce7f1";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-09-27-a3ce7f1.tar.gz";
              hash = "sha256-yiQPAujIJWT0yHFx6VjXTagvB7mQaxtyjubPSAn0rEQ=";
              directory = "roc_nightly-macos_x86_64-2026-09-27-a3ce7f1";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-09-27-a3ce7f1.tar.gz";
              hash = "sha256-jQT+sTTjFbdB8hk8DDozfhN86no/suzts0lfa+o48VQ=";
              directory = "roc_nightly-macos_apple_silicon-2026-09-27-a3ce7f1";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-09-27-a3ce7f1";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-09-27-a3ce7f1/${nightly.archive}";
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
