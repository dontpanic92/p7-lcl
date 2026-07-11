#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

"$repo_dir/generator/generate.py" --check
python3 -m unittest discover -s "$repo_dir/generator" -p 'test_*.py'
