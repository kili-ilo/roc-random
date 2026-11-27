#!/usr/bin/env bash
# Prints the Roc version pinned in examples/simple.roc as step outputs for roc-lang/setup-roc.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pin="$(sed -n 's/.*roc: "\([^"]*\)".*/\1/p' "$root_dir/examples/simple.roc" | head -n 1)"

case "$pin" in
    "")
        echo "examples/simple.roc does not pin a roc version" >&2
        exit 1
        ;;
    nightly-*)
        echo "version=nightly"
        echo "nightly_tag=$pin"
        ;;
    *)
        # The header pin 0.1.0-RC1 is the release 0.1.0_RC1.
        echo "version=${pin//-/_}"
        echo "nightly_tag="
        ;;
esac
