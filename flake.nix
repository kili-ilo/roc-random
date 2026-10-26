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
              archive = "roc_nightly-linux_x86_64-2026-10-26-3c0fffe.tar.gz";
              hash = "sha256-zneIQqONYwOPZxH1TzyQ1f4jfXlUM7AbHE1/Q+U5D/U=";
              directory = "roc_nightly-linux_x86_64-2026-10-26-3c0fffe";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-26-3c0fffe.tar.gz";
              hash = "sha256-d0Zs3IqHD2/vfjJ+gDeFjzN7kmaYEhwKemMMIPwf5hE=";
              directory = "roc_nightly-linux_arm64-2026-10-26-3c0fffe";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-26-3c0fffe.tar.gz";
              hash = "sha256-fjWP396GdV8z6c4nfJhL4I5G1dhP+1BqRjrkLljtx48=";
              directory = "roc_nightly-macos_x86_64-2026-10-26-3c0fffe";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-26-3c0fffe.tar.gz";
              hash = "sha256-n7WApyXdAVhJMHpq2fLgV1dCIwZLjyr8uIxhNudQt2Q=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-26-3c0fffe";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-26-3c0fffe";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-26-3c0fffe/${nightly.archive}";
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
