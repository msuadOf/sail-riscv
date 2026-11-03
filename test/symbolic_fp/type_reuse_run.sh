#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="${1:?用法: type_reuse_run.sh OUTPUT_DIR ISLA_PLUGIN}"
isla_plugin="${2:?用法: type_reuse_run.sh OUTPUT_DIR ISLA_PLUGIN}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"

cd "$test_dir"
sail --strict-var --strict-bitvector --strict-exponentials --require-version 0.20.1 \
  --memo-z3-path "$output_dir/sail_smt_cache" -D SYMBOLIC --all-modules \
  --just-check type_reuse.sail_project
sail -plugin "$isla_plugin" -isla --strict-var --strict-bitvector \
  --strict-exponentials --require-version 0.20.1 \
  --memo-z3-path "$output_dir/sail_smt_cache" --all-modules \
  --isla-preserve type_reuse_flags \
  --isla-preserve type_reuse_classify16 --isla-preserve type_reuse_classify32 \
  --isla-preserve type_reuse_classify64 \
  --isla-preserve type_reuse_unknown16 --isla-preserve type_reuse_unknown32 \
  --isla-preserve type_reuse_unknown64 \
  --isla-output-dir "$output_dir" -o type_reuse type_reuse.sail_project
CARGO_TARGET_DIR="$output_dir/cargo-target" cargo run -q \
  --manifest-path "$test_dir/type_reuse/Cargo.toml" -- \
  "$output_dir/type_reuse.ir"
