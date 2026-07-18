#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

for example in \
  hello \
  layout \
  input-events \
  collections \
  application \
  desktop-components \
  showcase
do
  echo "== examples/$example =="
  cargo run --quiet --manifest-path "$repo_dir/protosept/Cargo.toml" \
    -p p7-cli -- check "$repo_dir/examples/$example"
  cargo run --quiet --manifest-path "$repo_dir/protosept/Cargo.toml" \
    -p p7-cli -- build "$repo_dir/examples/$example"
  cargo run --quiet --manifest-path "$repo_dir/protosept/Cargo.toml" \
    -p p7-cli -- test "$repo_dir/examples/$example"
done
