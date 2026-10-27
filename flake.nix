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
              archive = "roc_nightly-linux_x86_64-2026-10-27-de79a0f.tar.gz";
              hash = "sha256-HvoL902TlkwnDmB2HtYUjy4TLDrfzFNhFJtRjvhIhkk=";
              directory = "roc_nightly-linux_x86_64-2026-10-27-de79a0f";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-27-de79a0f.tar.gz";
              hash = "sha256-mdP+WKeZXmGmcqixn/gsb57fpbHQmfG8z4QYEh6+9iw=";
              directory = "roc_nightly-linux_arm64-2026-10-27-de79a0f";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-27-de79a0f.tar.gz";
              hash = "sha256-2K4RhOf/3/IluQqqlDmdTB+XUAog5Gw4nEqLAusD2H8=";
              directory = "roc_nightly-macos_x86_64-2026-10-27-de79a0f";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-27-de79a0f.tar.gz";
              hash = "sha256-fe4ijnAkRyskBAH7Zp8wqOE8NyhuG7cQJ3IRT+WkwJQ=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-27-de79a0f";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-27-de79a0f";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-27-de79a0f/${nightly.archive}";
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
