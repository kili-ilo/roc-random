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
              archive = "roc_nightly-linux_x86_64-2026-11-02-847b82c.tar.gz";
              hash = "sha256-/mXw66HV9j2qrY+GUo2FkVCwXk3fQNh5OiA3nS1aqpY=";
              directory = "roc_nightly-linux_x86_64-2026-11-02-847b82c";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-11-02-847b82c.tar.gz";
              hash = "sha256-0gnqhmB0QcKtCCVhspC+4J4MTDMMRqZ9tYjWPfvgvxQ=";
              directory = "roc_nightly-linux_arm64-2026-11-02-847b82c";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-11-02-847b82c.tar.gz";
              hash = "sha256-bI50WiHjjnLZXuid8CnP5L0AJHf7g1E5LBpp/nLus+M=";
              directory = "roc_nightly-macos_x86_64-2026-11-02-847b82c";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-11-02-847b82c.tar.gz";
              hash = "sha256-VMLibaZ5tJ5CUTwIEQrFN+sGDDn63iCf+qeaG9JmBOE=";
              directory = "roc_nightly-macos_apple_silicon-2026-11-02-847b82c";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-11-02-847b82c";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-11-02-847b82c/${nightly.archive}";
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
