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
              archive = "roc_nightly-linux_x86_64-2026-11-19-54c51c9.tar.gz";
              hash = "sha256-zxV3wyuRxNvLzwVs3iU4jgYG+ZrNLpoDXPt2S2F1FLI=";
              directory = "roc_nightly-linux_x86_64-2026-11-19-54c51c9";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-11-19-54c51c9.tar.gz";
              hash = "sha256-lsUyoImczdOo5S79JIL9CVayev3I/AbwxEgodNrggt0=";
              directory = "roc_nightly-linux_arm64-2026-11-19-54c51c9";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-11-19-54c51c9.tar.gz";
              hash = "sha256-jCa+inixXQUirEuK9t5EJsuCDcg7Xrxife5vjFLtaSE=";
              directory = "roc_nightly-macos_x86_64-2026-11-19-54c51c9";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-11-19-54c51c9.tar.gz";
              hash = "sha256-dGh4q3+1b5fc0AF7fJMwy7Le6X1h8WpHmggZw8D5YL0=";
              directory = "roc_nightly-macos_apple_silicon-2026-11-19-54c51c9";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-11-19-54c51c9";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-11-19-54c51c9/${nightly.archive}";
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
