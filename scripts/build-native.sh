#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$repo_dir/native/lib"
mkdir -p "$repo_dir/target/lazarus-config"

"$repo_dir/generator/generate.py"

"$HOME/lazarus/lazbuild" \
  --quiet \
  --primary-config-path="$repo_dir/target/lazarus-config" \
  --lazarusdir="$HOME/lazarus" \
  --widgetset=cocoa \
  --opt=-k-ld_classic \
  "$repo_dir/native/pascal/p7lcl.lpi"
