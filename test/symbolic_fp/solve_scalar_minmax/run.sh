#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$test_dir/../../../.." && pwd)"
output_dir="${1:?usage: run.sh NEW_OUTPUT_DIR ISLA_PLUGIN}"
isla_plugin="${2:?usage: run.sh NEW_OUTPUT_DIR ISLA_PLUGIN}"
snapshot="${3:?usage: run.sh NEW_OUTPUT_DIR ISLA_PLUGIN PRE_EDIT_SNAPSHOT}"
python3 "$test_dir/build_probe.py" "$output_dir" "$snapshot"
output_dir="$(cd "$output_dir" && pwd)"
mapfile -t names < "$output_dir/names.txt"
preserve=()
for name in "${names[@]}"; do preserve+=(--isla-preserve "$name"); done
(
  cd "$output_dir"
  sail -D SYMBOLIC --strict-var --strict-bitvector --strict-exponentials \
    --require-version 0.20.1 --memo-z3-path memo --all-modules \
    --just-check probe.sail_project > typecheck.log 2>&1
  sail -plugin "$isla_plugin" -isla -D SYMBOLIC --strict-var \
    --strict-bitvector --strict-exponentials --require-version 0.20.1 \
    --memo-z3-path memo --all-modules "${preserve[@]}" \
    --isla-output-dir "$output_dir" -o scalar_minmax probe.sail_project \
    > ir-build.log 2>&1
)
python3 "$test_dir/check_ir.py" "$output_dir/scalar_minmax.ir" > "$output_dir/check-ir.log"
mkdir -p "$output_dir/runner/src"
cp "$test_dir/runner.rs" "$output_dir/runner/src/main.rs"
cat > "$output_dir/runner/Cargo.toml" <<EOF
[package]
name = "scalar_minmax_runner"
version = "0.1.0"
edition = "2021"

[dependencies]
isla-lib = { path = "$repo_root/isla/isla-lib" }

[workspace]
EOF
CARGO_TARGET_DIR="$output_dir/runner-target" cargo build --offline --release \
  --manifest-path "$output_dir/runner/Cargo.toml" > "$output_dir/runner-build.log" 2>&1
"$output_dir/runner-target/release/scalar_minmax_runner" \
  "$output_dir/scalar_minmax.ir" "$output_dir/names.txt" > "$output_dir/run.log" 2>&1
python3 - "$output_dir" "$test_dir" "$isla_plugin" <<'PY'
from hashlib import sha256
import json
from pathlib import Path
import sys

out, test, plugin = map(Path, sys.argv[1:])
paths = {
    "ir": out / "scalar_minmax.ir",
    "fixture": out / "probe.sail",
    "runner": out / "runner-target/release/scalar_minmax_runner",
    "builder": test / "build_probe.py",
    "production_helper": test.parents[2] / "model/extensions/FD/fp_minmax.sail",
    "plugin": plugin,
}
report = {name: sha256(path.read_bytes()).hexdigest() for name, path in paths.items()}
report["results"] = (out / "run.log").read_text().splitlines()
(out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
print(report["results"][-1])
PY
