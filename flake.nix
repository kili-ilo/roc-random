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
              archive = "roc_nightly-linux_x86_64-2026-10-18-1df370f.tar.gz";
              hash = "sha256-CCHqGpdy+SHwtOsc1AAjirtZsCR9soEPDqhlQm94Lp0=";
              directory = "roc_nightly-linux_x86_64-2026-10-18-1df370f";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-18-1df370f.tar.gz";
              hash = "sha256-UAWESeeGv5ve0ZyjuFGhwDD+p/yKyK6+0sfBKjdQWsQ=";
              directory = "roc_nightly-linux_arm64-2026-10-18-1df370f";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-18-1df370f.tar.gz";
              hash = "sha256-P+vYTA/ydM89ovpxr6/kqAOaEcaNd01IQGq2aWJ9zpY=";
              directory = "roc_nightly-macos_x86_64-2026-10-18-1df370f";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-18-1df370f.tar.gz";
              hash = "sha256-D1/h0ScUv1/MkG3VsA/QzNMd+5a7gnN7nW9szA6TwUc=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-18-1df370f";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-18-1df370f";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-18-1df370f/${nightly.archive}";
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
