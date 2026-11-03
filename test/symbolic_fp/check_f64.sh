#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="${1:?usage: check_f64.sh OUTPUT_DIR ISLA_PLUGIN}"
isla_plugin="${2:?usage: check_f64.sh OUTPUT_DIR ISLA_PLUGIN}"
mkdir -p "$output_dir"

cd "$test_dir"
names=(riscv_f64Eq riscv_f64Lt riscv_f64Lt_quiet riscv_f64Le riscv_f64Le_quiet
       riscv_f64Add riscv_f64Sub riscv_f64Mul riscv_f64Div riscv_f64Sqrt riscv_f64MulAdd
       riscv_f64roundToInt riscv_f64ToI32 riscv_f64ToUi32 riscv_f64ToI64 riscv_f64ToUi64
       riscv_i32ToF64 riscv_ui32ToF64 riscv_i64ToF64 riscv_ui64ToF64
       riscv_f64ToF16 riscv_f64ToF32)
preserve_args=()
for name in "${names[@]}"; do
  preserve_args+=(--isla-preserve "$name")
  preserve_args+=(--isla-preserve "f64_unknown_${name}_inputs")
done
sail --strict-var --strict-bitvector --strict-exponentials --require-version 0.20.1 \
  --memo-z3-path "$output_dir/sail_smt_cache" -D SYMBOLIC --all-modules \
  --just-check f64_probe.sail_project
sail -plugin "$isla_plugin" -isla --strict-var --strict-bitvector \
  --strict-exponentials --require-version 0.20.1 \
  --memo-z3-path "$output_dir/sail_smt_cache" --all-modules \
  "${preserve_args[@]}" \
  --isla-preserve f64_compare_probe --isla-preserve f64_arithmetic_probe \
  --isla-output-dir "$output_dir" -o f64_probe f64_probe.sail_project

ir="$output_dir/f64_probe.ir"
for name in "${names[@]}"; do
  rg -q "^val z${name} " "$ir"
  rg -q "^fn z${name}\\(" "$ir"
  rg -q "^fn zf64_unknown_${name}_inputs\\(" "$ir"
done
sail --strict-var --strict-bitvector --strict-exponentials \
  --require-version 0.20.1 --memo-z3-path "$output_dir/sail_smt_cache" \
  --all-modules --cpp --c-no-main --c-preserve f64_compare_probe \
  --c-preserve f64_arithmetic_probe -o "$output_dir/f64_cpp" f64_probe.sail_project
rg -q 'softfloat_f64eq\(' "$output_dir/f64_cpp.cpp"
rg -q 'softfloat_f64muladd\(' "$output_dir/f64_cpp.cpp"
printf 'f64 22 IR bodies present: %s\n' "$ir"
