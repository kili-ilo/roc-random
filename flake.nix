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
              archive = "roc_nightly-linux_x86_64-2026-08-23-fb208ba.tar.gz";
              hash = "sha256-MeUpvQhfvkWTZWp+tQehBaqEcqPM+EAH2oEJd304XR8=";
              directory = "roc_nightly-linux_x86_64-2026-08-23-fb208ba";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-08-23-fb208ba.tar.gz";
              hash = "sha256-D/aQBdgcsnh7cYj58342gMlEodV8BJcPNGJzy2+mTAk=";
              directory = "roc_nightly-linux_arm64-2026-08-23-fb208ba";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-08-23-fb208ba.tar.gz";
              hash = "sha256-ACFeDxCFIzKJ5H+w3euiuA9AmWQYR8WwusBzdd/ryIc=";
              directory = "roc_nightly-macos_x86_64-2026-08-23-fb208ba";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-08-23-fb208ba.tar.gz";
              hash = "sha256-75f+EKHx6gzsHI+uIHlfwz9x11glmF/+3kWDda4Eym0=";
              directory = "roc_nightly-macos_apple_silicon-2026-08-23-fb208ba";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-08-23-fb208ba";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-08-23-fb208ba/${nightly.archive}";
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
