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
              archive = "roc_nightly-linux_x86_64-2026-08-26-b29bef3.tar.gz";
              hash = "sha256-5ovsE+I7KH5HJTtC2KdXYbgGA5v97kYPacAYcuR++EY=";
              directory = "roc_nightly-linux_x86_64-2026-08-26-b29bef3";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-26-b29bef3.tar.gz";
              hash = "sha256-H2WvPytE9MCYJ6z0QuUfeVx2WGhf7O1XvIk5OgMf4Yw=";
              directory = "roc_nightly-linux_arm64-2026-08-26-b29bef3";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-26-b29bef3.tar.gz";
              hash = "sha256-aGB+/Dwa8b7gaXYoap+XkGBlBb+Mcv614tilYaTGYNk=";
              directory = "roc_nightly-macos_x86_64-2026-08-26-b29bef3";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-26-b29bef3.tar.gz";
              hash = "sha256-ccLm50Mr4Jpa0i29C/iA1RfVETxUL+OhkCwbgctXFwM=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-26-b29bef3";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-26-b29bef3";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-26-b29bef3/${nightly.archive}";
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
