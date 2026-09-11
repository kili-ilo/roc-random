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
              archive = "roc_nightly-linux_x86_64-2026-09-11-793f9d8.tar.gz";
              hash = "sha256-BNcBBOfdFd4znJUHv1NTAUQp2okG8C2zVVLuxjI3Aog=";
              directory = "roc_nightly-linux_x86_64-2026-09-11-793f9d8";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-09-11-793f9d8.tar.gz";
              hash = "sha256-yTnrIDuo745Am6Jr4MqJfdZm9XfS0rQya8VzNgkS4Pg=";
              directory = "roc_nightly-linux_arm64-2026-09-11-793f9d8";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-09-11-793f9d8.tar.gz";
              hash = "sha256-u/7B1sUcagwOmAnZwMGZif8eezzU6w3xR9Vrp8ZvV1c=";
              directory = "roc_nightly-macos_x86_64-2026-09-11-793f9d8";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-09-11-793f9d8.tar.gz";
              hash = "sha256-fuzepwT3cyF2jPXsKr6hpiRXh7LxlHn4sfBJRIxdm4w=";
              directory = "roc_nightly-macos_apple_silicon-2026-09-11-793f9d8";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-09-11-793f9d8";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-09-11-793f9d8/${nightly.archive}";
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
