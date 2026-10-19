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
              archive = "roc_nightly-linux_x86_64-2026-10-19-601b54c.tar.gz";
              hash = "sha256-oENYr3FW6wo4BQYALCyGKg2o2rIaEkDTZoHU6E6/uUc=";
              directory = "roc_nightly-linux_x86_64-2026-10-19-601b54c";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-19-601b54c.tar.gz";
              hash = "sha256-GKLZUQc4wXN56Teso4qn+v6FNbv6KS6s3lUnz26JOpk=";
              directory = "roc_nightly-linux_arm64-2026-10-19-601b54c";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-19-601b54c.tar.gz";
              hash = "sha256-PUfNGdE3L3RAErx8KZf+u68RE/jBJkpf1SjaT6Vgx4Y=";
              directory = "roc_nightly-macos_x86_64-2026-10-19-601b54c";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-19-601b54c.tar.gz";
              hash = "sha256-Ad8BesMHC8BsOwxU/T9mHDyUjvjL5MrI/i6lvkczxco=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-19-601b54c";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-19-601b54c";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-19-601b54c/${nightly.archive}";
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
