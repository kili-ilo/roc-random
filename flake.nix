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
              archive = "roc_nightly-linux_x86_64-2026-10-24-f6c6cfb.tar.gz";
              hash = "sha256-hpY6T1675j9aAXZixgLolGjBuKXQj2naRcCI0wBnVLo=";
              directory = "roc_nightly-linux_x86_64-2026-10-24-f6c6cfb";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-24-f6c6cfb.tar.gz";
              hash = "sha256-k/1GfBq5ZyIs2VSIOclC5qeqNrqENjdsIIehIAHBtKg=";
              directory = "roc_nightly-linux_arm64-2026-10-24-f6c6cfb";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-24-f6c6cfb.tar.gz";
              hash = "sha256-yvqgz3fqZOGTLMsJxK/Gw9uqi9wBEq3tnIpc9xtDd40=";
              directory = "roc_nightly-macos_x86_64-2026-10-24-f6c6cfb";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-24-f6c6cfb.tar.gz";
              hash = "sha256-a5S+vO3SASJ41XvyeZg/gSYcYMi/h67sJB0Ql+cho1o=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-24-f6c6cfb";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-24-f6c6cfb";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-24-f6c6cfb/${nightly.archive}";
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
