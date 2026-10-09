#!/usr/bin/env bash
# Copies the canonical Ruby engine into the npm and PyPI packages' vendor
# directories. Run before testing or publishing either wrapper. This keeps
# a single source of truth (lib/, exe/) instead of maintaining copies.
set -euo pipefail
cd "$(dirname "$0")/.."

for target in packages/npm/vendor packages/python/branchglide/vendor; do
  rm -rf "$target"
  mkdir -p "$target"
  cp -R lib "$target/lib"
  cp -R exe "$target/exe"
  cp branchglide.gemspec "$target/" 2>/dev/null || true
done

echo "Vendored lib/ and exe/ into packages/npm/vendor and packages/python/branchglide/vendor"
