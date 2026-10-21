#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="${1:?usage: build_runner.sh OUTPUT_DIR ISLA_LIB_DIR}"
isla_lib="${2:?usage: build_runner.sh OUTPUT_DIR ISLA_LIB_DIR}"
mkdir -p "$output_dir/src"
output_dir="$(cd "$output_dir" && pwd)"
isla_lib="$(cd "$isla_lib" && pwd)"
cp "$test_dir/runner.rs" "$output_dir/src/main.rs"
cat > "$output_dir/Cargo.toml" <<EOF
[package]
name = "vector_helper_runner"
version = "0.1.0"
edition = "2021"

[dependencies]
isla-lib = { path = "$isla_lib" }
EOF
cargo build --offline --release --manifest-path "$output_dir/Cargo.toml"
printf '%s\n' "$output_dir/target/release/vector_helper_runner"
