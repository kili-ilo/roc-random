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
              archive = "roc_nightly-linux_x86_64-2026-10-17-5f126ac.tar.gz";
              hash = "sha256-zusDGs83dLzO7kMuPrr5jlcTCNaw84opbDoeICXfjR0=";
              directory = "roc_nightly-linux_x86_64-2026-10-17-5f126ac";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-17-5f126ac.tar.gz";
              hash = "sha256-DYcWg3okjXPRhcp2o35kbBfzfY5IMVYXc9FL3M82lqk=";
              directory = "roc_nightly-linux_arm64-2026-10-17-5f126ac";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-17-5f126ac.tar.gz";
              hash = "sha256-BGonwlGtqWvkOZKgzxNxqaFhyNq6aZw9qV//TWyfURg=";
              directory = "roc_nightly-macos_x86_64-2026-10-17-5f126ac";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-17-5f126ac.tar.gz";
              hash = "sha256-VkZNohhYeUcSHED7Noeqd85JshrveB2f3s7t/O+J1KA=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-17-5f126ac";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-17-5f126ac";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-17-5f126ac/${nightly.archive}";
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
