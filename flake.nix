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
              archive = "roc_nightly-linux_x86_64-2026-09-17-9221bca.tar.gz";
              hash = "sha256-TFQvBD6YvJDfVonIoz4Fnv75+Srv0ft7LoNk6KzRdHY=";
              directory = "roc_nightly-linux_x86_64-2026-09-17-9221bca";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-09-17-9221bca.tar.gz";
              hash = "sha256-XxMEq6C+3D1iSCZvXQicpcEbWQAWy8QfT4MNgoRA+Pg=";
              directory = "roc_nightly-linux_arm64-2026-09-17-9221bca";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-09-17-9221bca.tar.gz";
              hash = "sha256-URVgCU3DFNdoL1tG/z59C+Os4eJDvGcvMe9h6b0S8BI=";
              directory = "roc_nightly-macos_x86_64-2026-09-17-9221bca";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-09-17-9221bca.tar.gz";
              hash = "sha256-jgCUcGv73tlFWOEyOZjhMx7CLFeOPoaviSwhKPrY9Fo=";
              directory = "roc_nightly-macos_apple_silicon-2026-09-17-9221bca";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-09-17-9221bca";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-09-17-9221bca/${nightly.archive}";
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
