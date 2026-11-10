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
              archive = "roc_nightly-linux_x86_64-2026-11-10-f7d1f19.tar.gz";
              hash = "sha256-iR8eBdFUlMt/Km5LdH5M4WH0WH5md7rAYq79ZzirWLk=";
              directory = "roc_nightly-linux_x86_64-2026-11-10-f7d1f19";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-11-10-f7d1f19.tar.gz";
              hash = "sha256-XslfXhm/T1r9X9ckRjHDnJH7ib2GXCnIzKyYc06gIM8=";
              directory = "roc_nightly-linux_arm64-2026-11-10-f7d1f19";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-11-10-f7d1f19.tar.gz";
              hash = "sha256-pYeNP/trw3FsrxpmEZGRrzol1H8qJitv3+G+HEwtP2s=";
              directory = "roc_nightly-macos_x86_64-2026-11-10-f7d1f19";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-11-10-f7d1f19.tar.gz";
              hash = "sha256-aNzJBsi9m5hKZ0ZyWNfOvD1k4UvkpHOwYUiH0O7JnEo=";
              directory = "roc_nightly-macos_apple_silicon-2026-11-10-f7d1f19";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-11-10-f7d1f19";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-11-10-f7d1f19/${nightly.archive}";
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
