#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
workspace="$(cd "$test_dir/../../.." && pwd)"
candidate="${RV32_FP_SAIL_SRC:-/tmp/isla-float-d-20260926/sail-riscv-candidate}"
plugin="${RV32_FP_ISLA_PLUGIN:-/tmp/isla-float-d-20260926/plugin/_build/default/sail_plugin_isla.cmxs}"
output="${1:?usage: run.sh EXTERNAL_OUTPUT_DIRECTORY}"

mkdir -p "$output" "$output/probe" "$output/runner/src"
output="$(cd "$output" && pwd)"
test "$output" != "$workspace" && [[ "$output" != "$workspace/"* ]]
test -f "$plugin" && test -f "$candidate/model/riscv.sail_project"

cmake -S "$candidate" -B "$output/cmake" -DDOWNLOAD_GMP=OFF -DCMAKE_BUILD_TYPE=Release \
    > "$output/cmake.log" 2>&1
model_config="$output/cmake/config/rv32d_v128_e64.json"
python3 - "$model_config" <<'PY'
import json, pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text()
text = re.sub(r'//[^\n]*', '', text)
config = json.loads(text)
assert config['base']['xlen'] == 32
assert config['extensions']['V']['vlen_exp'] == 7
assert config['extensions']['V']['elen_exp'] == 6
for ext in ['F', 'D', 'Zfa', 'Zca', 'Zcf']:
    assert config['extensions'][ext]['supported'] is True, ext
PY

(
    cd "$candidate/model"
    # Sail ignores extra .sail arguments when --all-modules consumes a project.
    # Flatten the project's ordered file list, then append the isolated probe.
    mapfile -td ';' sail_files < <(sail --list-files-separated ';' --all-modules riscv.sail_project | tr -d '\n'; printf ';')
    sail -plugin "$plugin" -isla --strict-var --strict-bitvector --strict-exponentials \
        --require-version 0.20.1 --memo-z3-path "$output/sail_smt_cache" \
        --isla-preserve encdec_compressed_forwards \
        --isla-preserve encdec_compressed_forwards_matches \
        --isla-preserve encdec_compressed_backwards \
        --isla-preserve encdec_compressed_backwards_matches \
        --isla-preserve rv32_fp_probe_fmvh \
        --isla-preserve rv32_fp_probe_fmvp \
        --isla-preserve rv32_fp_probe_c_flw \
        --isla-preserve rv32_fp_probe_c_flwsp \
        --isla-preserve rv32_fp_probe_c_fsw \
        --isla-preserve rv32_fp_probe_c_fswsp \
        --isla-output-dir "$output/probe" -o rv32_fp_probe \
        --config "$model_config" "${sail_files[@]}" "$test_dir/probe.sail"
) > "$output/ir.log" 2>&1
ir="$output/probe/rv32_fp_probe.ir"
for name in zext_decode zext_decode_compressed zexecute zrv32_fp_probe_fmvh \
    zrv32_fp_probe_fmvp zrv32_fp_probe_c_flw zrv32_fp_probe_c_flwsp \
    zrv32_fp_probe_c_fsw zrv32_fp_probe_c_fswsp zriscv_f32Add; do
    rg -q "^fn $name\\(" "$ir"
done

cp "$test_dir/runner.rs" "$output/runner/src/main.rs"
cat > "$output/runner/Cargo.toml" <<EOF
[package]
name = "isla-rv32-fp-probe"
version = "0.1.0"
edition = "2021"

[dependencies]
isla-lib = { path = "$workspace/isla/isla-lib" }
serde_json = "1"
EOF

z3_prefix="${Z3_PREFIX:-/home/linuxbrew/.linuxbrew/opt/z3}"
RUSTFLAGS="-L native=$z3_prefix/lib -C link-arg=-Wl,-rpath,$z3_prefix/lib" \
CARGO_TARGET_DIR="$output/runner/target" \
    cargo run --quiet --manifest-path "$output/runner/Cargo.toml" -- \
    "$ir" "$test_dir/riscv32_fp.toml" "$test_dir/cases.json" "$output/results.json" \
    > "$output/runner.log" 2>&1
python3 "$test_dir/test_results.py" "$output/results.json"

{
    date -u '+UTC=%Y-%m-%dT%H:%M:%SZ'
    git -C "$candidate" rev-parse HEAD
    sail --version
    sha256sum "$model_config" "$ir" "$plugin" "$test_dir/probe.sail" \
        "$test_dir/runner.rs" "$test_dir/riscv32_fp.toml" "$output/results.json"
} > "$output/manifest.txt"
