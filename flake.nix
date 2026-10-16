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
              archive = "roc_nightly-linux_x86_64-2026-10-16-f14c106.tar.gz";
              hash = "sha256-9HE7hUDVnMxx0hfcEjySa6R4JH0t2mBaZz70F7bx3Qc=";
              directory = "roc_nightly-linux_x86_64-2026-10-16-f14c106";
            };
            aarch64-linux = {
              archive = "roc_nightly-linux_arm64-2026-10-16-f14c106.tar.gz";
              hash = "sha256-EuklpGA9td2xXKh/GzjYRrdvQ+n7YkE0ItkEysxlRS4=";
              directory = "roc_nightly-linux_arm64-2026-10-16-f14c106";
            };
            x86_64-darwin = {
              archive = "roc_nightly-macos_x86_64-2026-10-16-f14c106.tar.gz";
              hash = "sha256-LA1tyVvP8SrDBQ+WrgWa3ApJKYmQdL6SGqlxuiGY15c=";
              directory = "roc_nightly-macos_x86_64-2026-10-16-f14c106";
            };
            aarch64-darwin = {
              archive = "roc_nightly-macos_apple_silicon-2026-10-16-f14c106.tar.gz";
              hash = "sha256-iV0FHWk5ljCPTHLM042AWONnxbdeoDEXx+sjnxvzYKA=";
              directory = "roc_nightly-macos_apple_silicon-2026-10-16-f14c106";
            };
          }.${pkgs.stdenv.hostPlatform.system};

          roc-nightly = pkgs.stdenvNoCC.mkDerivation {
            pname = "roc-nightly";
            version = "2026-10-16-f14c106";
            src = pkgs.fetchurl {
              url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-16-f14c106/${nightly.archive}";
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
