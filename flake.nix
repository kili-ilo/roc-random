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
          # Written by scripts/update_roc_version.py.
          roc-version = "0.1.0-RC1";
          roc-url = "https://github.com/roc-lang/roc/releases/download/0.1.0_RC1";
          roc-archive =
            {
              x86_64-linux = {
                name = "roc-linux_x86_64-0.1.0_RC1";
                hash = "sha256-BDxCbqhdzb1CeVHq7SRvDBDBcdmI8lmHgiM6ba5DN50=";
              };
              aarch64-linux = {
                name = "roc-linux_arm64-0.1.0_RC1";
                hash = "sha256-s+Cp28ki84AnAqVaGGmtLC5PTck12KnRsmw2EmaN/0M=";
              };
              x86_64-darwin = {
                name = "roc-macos_x86_64-0.1.0_RC1";
                hash = "sha256-6ps4teRwjL5CySB36Bb1JBKZ2hqj9MRujLkzsaoq+Fg=";
              };
              aarch64-darwin = {
                name = "roc-macos_apple_silicon-0.1.0_RC1";
                hash = "sha256-6CKAQMcB4TAlTHJTmh0PGxUNeMAAWHR+2w7a5Rul28g=";
              };
            }
            .${pkgs.stdenv.hostPlatform.system};

          roc = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc";
            version = roc-version;
            src = pkgs.fetchurl {
              url = "${roc-url}/${roc-archive.name}.tar.gz";
              inherit (roc-archive) hash;
            };
            dontBuild = true;
            unpackPhase = "tar -xzf $src";
            sourceRoot = ".";
            installPhase = ''
              install -Dm755 ${roc-archive.name}/roc $out/bin/roc
            '';
          };
        in
        {
          devShells.default = pkgs.mkShell {
            name = "roc-random";
            packages = [
              roc
              pkgs.actionlint
              pkgs.nixfmt-rfc-style
              pkgs.nodePackages.prettier
            ];
          };
          formatter = pkgs.nixfmt-rfc-style;
        };
    };
}
