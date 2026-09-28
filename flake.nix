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
              archive = "roc_nightly-linux_x86_64-2026-09-28-9927ba8.tar.gz";
              hash = "sha256-qoi9U4v92vkMxjdUJ1gtnq0fGVlzaEf7aRnZAtM8S5c=";
              directory = "roc_nightly-linux_x86_64-2026-09-28-9927ba8";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-09-28-9927ba8.tar.gz";
              hash = "sha256-1M4aD4y+4MqLszGhnHOCtXvwo05GpP2Cwo/5rToDQRY=";
              directory = "roc_nightly-linux_arm64-2026-09-28-9927ba8";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-09-28-9927ba8.tar.gz";
              hash = "sha256-2LUQ7v5vhSTMYXW83lUC9xO6qe9QwwCkQNok5IYeJk0=";
              directory = "roc_nightly-macos_x86_64-2026-09-28-9927ba8";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-09-28-9927ba8.tar.gz";
              hash = "sha256-2Y3QsLxGKKd820e8hD23rd8EP3j+ivURbGOMvUShi/A=";
              directory = "roc_nightly-macos_apple_silicon-2026-09-28-9927ba8";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-09-28-9927ba8";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-09-28-9927ba8/${nightly.archive}";
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
