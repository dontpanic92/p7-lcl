#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/p7-lcl-abi.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

"${CC:-cc}" \
  -std=c11 \
  -Wall \
  -Wextra \
  -Werror \
  -I"$repo_dir/protosept/p7/include" \
  "$repo_dir/native/tests/abi_compat.c" \
  -o "$tmp_dir/abi_compat"
"$tmp_dir/abi_compat" "$repo_dir/native/lib/libp7lcl.dylib"

/usr/local/bin/fpc \
  -Fu"$repo_dir/native/pascal" \
  -FU"$tmp_dir" \
  -FE"$tmp_dir" \
  -oabi_layout \
  "$repo_dir/native/tests/abi_layout.pas" >/dev/null
"$tmp_dir/abi_layout"

cargo test \
  --quiet \
  --manifest-path "$repo_dir/protosept/Cargo.toml" \
  -p p7 \
  --test native_extension_abi \
  abi_layout_matches_c_contract
cargo test \
  --quiet \
  --manifest-path "$repo_dir/protosept/Cargo.toml" \
  -p p7 \
  --test native_extension_abi \
  native_function_descriptor_struct_size
