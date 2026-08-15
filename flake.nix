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
              archive = "roc_nightly-linux_x86_64-2026-08-15-f70f90a.tar.gz";
              hash = "sha256-f9GCv8a3YR906Y2WYiUGtsG2neB+bPXEEHDVdXzQpnw=";
              directory = "roc_nightly-linux_x86_64-2026-08-15-f70f90a";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-15-f70f90a.tar.gz";
              hash = "sha256-yJSErMFLUetyg5tYTYIbP3BvxEnKK/GIRxMfrWMz3EE=";
              directory = "roc_nightly-linux_arm64-2026-08-15-f70f90a";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-15-f70f90a.tar.gz";
              hash = "sha256-R+zjFAhtP0FL2dV0lF8OHR/B+l8m3RH0+KA8LtzfhFA=";
              directory = "roc_nightly-macos_x86_64-2026-08-15-f70f90a";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-15-f70f90a.tar.gz";
              hash = "sha256-viWG8QyVaRKk7UDJjT8EfCozvFmbn65mPN97tzPcn9U=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-15-f70f90a";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-15-f70f90a";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-15-f70f90a/${nightly.archive}";
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
