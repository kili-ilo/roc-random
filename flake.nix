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
              archive = "roc_nightly-linux_x86_64-2026-08-28-981de43.tar.gz";
              hash = "sha256-AfVp6CGOSkfwzvdCBLpnHFfCnpU9dYYL9bd5JD3uVIc=";
              directory = "roc_nightly-linux_x86_64-2026-08-28-981de43";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-28-981de43.tar.gz";
              hash = "sha256-9F5JzA0eEn8KzBOIVxcMmbzj9WpGP+T87+7xiMOexfQ=";
              directory = "roc_nightly-linux_arm64-2026-08-28-981de43";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-28-981de43.tar.gz";
              hash = "sha256-60gipSlxM504+gqbiJrazsaX6m1N3bbcQSvZEnC7h34=";
              directory = "roc_nightly-macos_x86_64-2026-08-28-981de43";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-28-981de43.tar.gz";
              hash = "sha256-zh9zpi7CZdmWrLrC14zQ9ZGBH+q5/y7L2kdV2idJoA4=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-28-981de43";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-28-981de43";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-28-981de43/${nightly.archive}";
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
