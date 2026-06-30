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

rm -rf "$tmp_dir"
mkdir -p "$docs_dir"

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
    "$ROC_BIN" check "$roc_file"
done

echo ""
echo "Running package tests..."
"$ROC_BIN" test package/main.roc

echo ""
echo "Running example tests..."
for roc_file in examples/*.roc; do
    "$ROC_BIN" test "$roc_file"
done

echo ""
echo "Generating package docs..."
"$ROC_BIN" docs package/main.roc --output="$docs_dir"

echo ""
echo "Completed all tests."
