#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$test_dir/../../.." && pwd)"
output_dir="${1:?usage: run_f16_wrapper.sh OUTPUT_DIR IR_FILE ORACLE_BIN [--quick]}"
ir_file="${2:?usage: run_f16_wrapper.sh OUTPUT_DIR IR_FILE ORACLE_BIN [--quick]}"
oracle_bin="${3:?usage: run_f16_wrapper.sh OUTPUT_DIR IR_FILE ORACLE_BIN [--quick]}"
mkdir -p "$output_dir/src"
cp "$test_dir/f16_wrapper_probe.rs" "$output_dir/src/main.rs"
cat > "$output_dir/Cargo.toml" <<EOF
[package]
name = "sail-symbolic-f16-wrapper"
version = "0.1.0"
edition = "2021"

[dependencies]
isla-lib = { path = "$repo_root/isla/isla-lib" }
EOF
CARGO_TARGET_DIR="$output_dir/target" cargo build --quiet --manifest-path "$output_dir/Cargo.toml"
python3 "$test_dir/f16_wrapper_cases.py" --oracle "$oracle_bin" \
  --probe "$output_dir/target/debug/sail-symbolic-f16-wrapper" --ir "$ir_file" "${@:4}"
