#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$test_dir/../../.." && pwd)"
output_dir="${1:?usage: run_f64.sh OUTPUT_DIR IR_FILE CASES_FILE}"
ir_file="${2:?usage: run_f64.sh OUTPUT_DIR IR_FILE CASES_FILE}"
cases_file="${3:?usage: run_f64.sh OUTPUT_DIR IR_FILE CASES_FILE}"
mkdir -p "$output_dir/src"
cp "$test_dir/run_f64.rs" "$output_dir/src/main.rs"
cat > "$output_dir/Cargo.toml" <<EOF
[package]
name = "sail-symbolic-fp-f64"
version = "0.1.0"
edition = "2021"

[dependencies]
isla-lib = { path = "$repo_root/isla/isla-lib" }
EOF
CARGO_TARGET_DIR="$output_dir/target" cargo run --quiet --manifest-path "$output_dir/Cargo.toml" -- "$ir_file" "$cases_file"
