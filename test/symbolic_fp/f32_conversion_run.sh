#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$test_dir/../../.." && pwd)"
output_dir="${1:?usage: f32_conversion_run.sh OUTPUT_DIR IR_FILE CASES_FILE}"
ir_file="${2:?usage: f32_conversion_run.sh OUTPUT_DIR IR_FILE CASES_FILE}"
cases_file="${3:?usage: f32_conversion_run.sh OUTPUT_DIR IR_FILE CASES_FILE}"
mkdir -p "$output_dir/src"
cp "$test_dir/f32_conversion_probe.rs" "$output_dir/src/main.rs"
cat > "$output_dir/Cargo.toml" <<EOF
[package]
name = "sail-f32-conversion-probe"
version = "0.1.0"
edition = "2021"

[dependencies]
isla-lib = { path = "$repo_root/isla/isla-lib" }
EOF
CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$output_dir/target}" \
  cargo run --quiet --manifest-path "$output_dir/Cargo.toml" -- "$ir_file" < "$cases_file"
