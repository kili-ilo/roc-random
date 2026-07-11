#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

ROC_BIN="${ROC:-roc}"

if [ -n "${ROC_RANDOM_TMPDIR:-}" ]; then
    tmp_base="$ROC_RANDOM_TMPDIR"
else
    tmp_base="$root_dir/.roc-random-tmp"
fi
export ROC_RANDOM_TMPDIR="$tmp_base"
export ROC="$ROC_BIN"

tmp_dir="$tmp_base/roc-random-ci"
docs_dir="$tmp_dir/docs"
bundle_dir="$tmp_dir/bundle"

rm -rf "$tmp_dir"
mkdir -p "$docs_dir" "$bundle_dir"

echo "$("$ROC_BIN" version)"

echo ""
echo "Checking format..."
"$ROC_BIN" fmt --check package examples

echo ""
echo "Checking package..."
"$ROC_BIN" check package/main.roc

echo ""
echo "Checking examples..."
for roc_file in examples/*.roc; do
    if ! grep -Eq '^[[:space:]]*rand:[[:space:]]*"\.\./package/main\.roc"' "$roc_file"; then
        echo "$roc_file must use local rand dependency: ../package/main.roc" >&2
        exit 1
    fi
    "$ROC_BIN" check "$roc_file"
done

echo ""
echo "Running package tests..."
"$ROC_BIN" test package/main.roc

echo ""
echo "Running Python oracle tests..."
python3 ci/random_oracle_tests.py

echo ""
echo "Running example tests..."
for roc_file in examples/*.roc; do
    "$ROC_BIN" test "$roc_file"
done

echo ""
echo "Generating package docs..."
"$ROC_BIN" docs package/main.roc --output="$docs_dir"

case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
        echo ""
        echo "Skipping package bundling on Windows."
        exit 0
        ;;
esac

echo ""
echo "Bundling package..."
scripts/bundle.sh --output-dir "$bundle_dir"

echo ""
echo "Testing examples against localhost bundle..."
python3 ci/test_bundle_examples.py

echo ""
echo "Completed all tests."
