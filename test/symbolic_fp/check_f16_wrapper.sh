#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="${1:?usage: check_f16_wrapper.sh OUTPUT_DIR ISLA_PLUGIN}"
isla_plugin="${2:?usage: check_f16_wrapper.sh OUTPUT_DIR ISLA_PLUGIN}"
mkdir -p "$output_dir"

names=(
  riscv_f16Add riscv_f16Sub riscv_f16Mul riscv_f16Div
  riscv_f16MulAdd riscv_f16Sqrt
  riscv_f16Lt riscv_f16Lt_quiet riscv_f16Le riscv_f16Le_quiet riscv_f16Eq
  riscv_f16ToI32 riscv_f16ToUi32 riscv_f16ToI64 riscv_f16ToUi64
  riscv_i32ToF16 riscv_ui32ToF16 riscv_i64ToF16 riscv_ui64ToF16
  riscv_f16roundToInt riscv_f16ToF32 riscv_f16ToF64
)

preserves=()
for name in "${names[@]}"; do
  preserves+=(--isla-preserve "$name")
done
preserves+=(--isla-preserve f16_wrapper_unknown_add)
preserves+=(--isla-preserve f16_wrapper_unknown_eq)
preserves+=(--isla-preserve f16_wrapper_unknown_i32_to_f16)

cd "$test_dir"
sail --strict-var --strict-bitvector --strict-exponentials --require-version 0.20.1 \
  -D SYMBOLIC --all-modules --just-check f16_wrapper.sail_project
sail -plugin "$isla_plugin" -isla --strict-var --strict-bitvector \
  --strict-exponentials --require-version 0.20.1 --all-modules \
  "${preserves[@]}" --isla-output-dir "$output_dir" \
  -o f16_wrapper f16_wrapper.sail_project

ir="$output_dir/f16_wrapper.ir"
for name in "${names[@]}"; do
  rg -q "^val z${name} " "$ir"
  rg -q "^fn z${name}\\(" "$ir"
done
rg -q '"fp_add"' "$ir"
rg -q '"fp_fma"' "$ir"
rg -q '"fp16_to_ieee"' "$ir"
rg -q '^fn zf16_wrapper_unknown_add\(' "$ir"
rg -q '^fn zf16_wrapper_unknown_eq\(' "$ir"
rg -q '^fn zf16_wrapper_unknown_i32_to_f16\(' "$ir"

sail --strict-var --strict-bitvector --strict-exponentials --require-version 0.20.1 \
  --all-modules --cpp --c-no-main --c-preserve f16_wrapper_cpp_probe \
  -o "$output_dir/f16_wrapper_cpp" f16_wrapper.sail_project
rg -q 'softfloat_f16add\(' "$output_dir/f16_wrapper_cpp.cpp"
printf 'f16 wrapper strict/IR/C++ structure PASS: %s\n' "$ir"
