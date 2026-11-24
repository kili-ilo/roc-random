#!/usr/bin/env bash
# Downloads Roc and adds it to the PATH of later GitHub Actions steps.
# roc-lang/setup-roc only installs nightlies, this also installs releases.
# Usage: ci/install_roc.sh 0.1.0-RC1
#        ci/install_roc.sh nightly-2026-11-21-09f4dc3
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: ci/install_roc.sh VERSION" >&2
    exit 1
fi
version="$1"

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) platform="linux_x86_64" ;;
    Linux-aarch64 | Linux-arm64) platform="linux_arm64" ;;
    Darwin-x86_64) platform="macos_x86_64" ;;
    Darwin-arm64) platform="macos_apple_silicon" ;;
    *)
        echo "Unsupported platform: $(uname -sm)" >&2
        exit 1
        ;;
esac

if [[ "$version" =~ ^nightly-([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9a-f]+)$ ]]; then
    archive="roc_nightly-$platform-${BASH_REMATCH[1]}"
    url="https://github.com/roc-lang/nightlies/releases/download/$version/$archive.tar.gz"
elif [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9]+)?$ ]]; then
    # The header pin 0.1.0-RC1 is the release 0.1.0_RC1.
    release="${version//-/_}"
    archive="roc-$platform-$release"
    url="https://github.com/roc-lang/roc/releases/download/$release/$archive.tar.gz"
else
    echo "Expected a release like 0.1.0-RC1 or a nightly like nightly-2026-11-21-09f4dc3, got: $version" >&2
    exit 1
fi

install_dir="${RUNNER_TEMP:-$(mktemp -d)}/roc"
rm -rf "$install_dir"
mkdir -p "$install_dir"
curl --fail --silent --show-error --location --retry 5 --retry-all-errors "$url" | tar -xz -C "$install_dir"

roc_dir="$install_dir/$archive"
"$roc_dir/roc" version

if [ -n "${GITHUB_PATH:-}" ]; then
    echo "$roc_dir" >>"$GITHUB_PATH"
else
    echo "Installed $roc_dir/roc"
fi
