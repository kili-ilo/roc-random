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
              archive = "roc_nightly-linux_x86_64-2026-08-21-90da19f.tar.gz";
              hash = "sha256-hRdOlxfrxMCxMetUX6oShMeD+tGkkuIRvdhhPSOHEtM=";
              directory = "roc_nightly-linux_x86_64-2026-08-21-90da19f";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-21-90da19f.tar.gz";
              hash = "sha256-f696Zepq1ksQpTI4VgsmjFUDk25e79ISkah8YzKzRq8=";
              directory = "roc_nightly-linux_arm64-2026-08-21-90da19f";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-21-90da19f.tar.gz";
              hash = "sha256-1dFojU/91uXxGgIumBc2bZuXr8nbP7z5YEwfODUHzno=";
              directory = "roc_nightly-macos_x86_64-2026-08-21-90da19f";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-21-90da19f.tar.gz";
              hash = "sha256-Vbgl+ZAn0jfU1Nxn8dhrb+u7whALe31N5HGuJ7gE2Tg=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-21-90da19f";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-21-90da19f";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-21-90da19f/${nightly.archive}";
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
