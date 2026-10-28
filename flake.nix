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
              archive = "roc_nightly-linux_x86_64-2026-10-28-bad769b.tar.gz";
              hash = "sha256-rqy+tg8nPqhWV6AD4uw5RhWV8yYbtpyeFuoYplY66Nk=";
              directory = "roc_nightly-linux_x86_64-2026-10-28-bad769b";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-28-bad769b.tar.gz";
              hash = "sha256-D1GoBJK3C0woLwuVd9dNKerUAAAkvH2wSjCNYQLoKu8=";
              directory = "roc_nightly-linux_arm64-2026-10-28-bad769b";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-28-bad769b.tar.gz";
              hash = "sha256-KSyAWVkYGUaLoH3GlMgkhoXd124lnQMcvQfnxsneoWo=";
              directory = "roc_nightly-macos_x86_64-2026-10-28-bad769b";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-28-bad769b.tar.gz";
              hash = "sha256-aZOfNTWyl3RlN56Aahlq/+28ZTEFRUedWmOO9tFTBMc=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-28-bad769b";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-28-bad769b";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-28-bad769b/${nightly.archive}";
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
