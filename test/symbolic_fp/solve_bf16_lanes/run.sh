#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$test_dir/../../../.." && pwd)"
output_dir="${1:?usage: run.sh OUTPUT_DIR ISLA_PLUGIN}"
isla_plugin="${2:?usage: run.sh OUTPUT_DIR ISLA_PLUGIN}"
mkdir -p "$output_dir/src"

cd "$test_dir"
sail -D SYMBOLIC --strict-var --strict-bitvector --strict-exponentials \
  --require-version 0.20.1 --memo-z3-path "$output_dir/memo" \
  --all-modules --just-check probe.sail_project
sail -plugin "$isla_plugin" -isla -D SYMBOLIC --strict-var --strict-bitvector \
  --strict-exponentials --require-version 0.20.1 --memo-z3-path "$output_dir/memo" \
  --all-modules --isla-preserve bf16_unknown_equivalence \
  --isla-preserve bf16_unknown_new --isla-output-dir "$output_dir" \
  -o bf16_lanes probe.sail_project
python3 - "$output_dir/bf16_lanes.ir" <<'PY'
from pathlib import Path
import re
import sys

ir = Path(sys.argv[1]).read_text()
body = ir.split("fn zbf16_to_f32(", 1)[1].split("\nfn ", 1)[0]
assert len(re.findall(r"= zeq_anything(?:zIB\d+zK)?\(", body)) == 3, "BF16 classification was specialized"
assert "= zeq_bits(" not in body and "= zneq_bits(" not in body
print("BF16 production conversion IR retains three generic comparisons")
PY
cp "$test_dir/run.rs" "$output_dir/src/main.rs"
cat > "$output_dir/Cargo.toml" <<EOF
[package]
name = "sail-bf16-lane-equivalence"
version = "0.1.0"
edition = "2021"

[dependencies]
isla-lib = { path = "$repo_root/isla/isla-lib" }
EOF
CARGO_TARGET_DIR="$output_dir/target" cargo run --quiet --offline --manifest-path "$output_dir/Cargo.toml" -- "$output_dir/bf16_lanes.ir" | tee "$output_dir/run-result.log"
python3 - "$output_dir" "$repo_root" <<'PY'
from hashlib import sha256
from pathlib import Path
import json
import sys

output = Path(sys.argv[1])
repo = Path(sys.argv[2])
paths = {
    "ir": output / "bf16_lanes.ir",
    "bf16_helper": repo / "sail-riscv/model/extensions/bfloat16/zfbfmin_utils.sail",
    "bf16_convert_lanes": repo / "sail-riscv/model/extensions/bfloat16/zvfbfmin_insts.sail",
    "bf16_macc_lanes": repo / "sail-riscv/model/extensions/bfloat16/zvfbfwma_insts.sail",
    "fp_core": repo / "sail-riscv/model/core/ieee_fp_exceptions.sail",
    "probe": repo / "sail-riscv/test/symbolic_fp/solve_bf16_lanes/probe.sail",
    "runner": repo / "sail-riscv/test/symbolic_fp/solve_bf16_lanes/run.rs",
}
manifest = {name: sha256(path.read_bytes()).hexdigest() for name, path in paths.items()}
manifest["result"] = (output / "run-result.log").read_text().strip().splitlines()[-1]
(output / "report.json").write_text(json.dumps(manifest, indent=2) + "\n")
PY
