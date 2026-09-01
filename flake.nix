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
              archive = "roc_nightly-linux_x86_64-2026-09-01-24e3995.tar.gz";
              hash = "sha256-ZQfnjUd+CctFx8ef2xAa2XYLqC3KqYub1tEH8r13CB8=";
              directory = "roc_nightly-linux_x86_64-2026-09-01-24e3995";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-09-01-24e3995.tar.gz";
              hash = "sha256-+xb9/6PfBndJq4Og5gfmp7/W21OKmpgcpo849aCxKXk=";
              directory = "roc_nightly-linux_arm64-2026-09-01-24e3995";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-09-01-24e3995.tar.gz";
              hash = "sha256-QzAJ2nfe2z3hboA3kR9xljlQwpILhh2tx4RxX5GIOEY=";
              directory = "roc_nightly-macos_x86_64-2026-09-01-24e3995";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-09-01-24e3995.tar.gz";
              hash = "sha256-f55HeG4smjo1VcUFpqF573WpBPr9ZnG8b+0pNYEbULA=";
              directory = "roc_nightly-macos_apple_silicon-2026-09-01-24e3995";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-09-01-24e3995";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-09-01-24e3995/${nightly.archive}";
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
