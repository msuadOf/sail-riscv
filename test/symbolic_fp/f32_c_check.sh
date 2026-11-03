#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="${1:?usage: f32_c_check.sh OUTPUT_DIR ISLA_PLUGIN}"
isla_plugin="${2:?usage: f32_c_check.sh OUTPUT_DIR ISLA_PLUGIN}"
mkdir -p "$output_dir"

cd "$test_dir"
sail --strict-var --strict-bitvector --strict-exponentials --require-version 0.20.1 \
  --memo-z3-path "$output_dir/sail_smt_cache" -D SYMBOLIC --all-modules \
  --just-check f32_c.sail_project
sail -plugin "$isla_plugin" -isla --strict-var --strict-bitvector \
  --strict-exponentials --require-version 0.20.1 \
  --memo-z3-path "$output_dir/sail_smt_cache" --all-modules \
  --isla-preserve riscv_f32Eq \
  --isla-preserve riscv_f32Lt --isla-preserve riscv_f32Lt_quiet \
  --isla-preserve riscv_f32Le --isla-preserve riscv_f32Le_quiet \
  --isla-preserve riscv_f32Add --isla-preserve riscv_f32Sub \
  --isla-preserve riscv_f32Mul --isla-preserve riscv_f32Div \
  --isla-preserve riscv_f32Sqrt --isla-preserve riscv_f32MulAdd \
  --isla-preserve riscv_f32roundToInt \
  --isla-preserve riscv_f32ToI32 --isla-preserve riscv_f32ToUi32 \
  --isla-preserve riscv_f32ToI64 --isla-preserve riscv_f32ToUi64 \
  --isla-preserve riscv_i32ToF32 --isla-preserve riscv_ui32ToF32 \
  --isla-preserve riscv_i64ToF32 --isla-preserve riscv_ui64ToF32 \
  --isla-preserve riscv_f32ToF16 --isla-preserve riscv_f32ToF64 \
  --isla-preserve riscv_f32ToBF16 \
  --isla-preserve ieee_add32_probe --isla-preserve ieee_sub32_probe \
  --isla-preserve ieee_mul32_probe --isla-preserve ieee_div32_probe \
  --isla-preserve ieee_sqrt32_probe --isla-preserve ieee_fma32_probe \
  --isla-preserve ieee_eq32_probe --isla-preserve ieee_lt32_probe \
  --isla-preserve ieee_lt_quiet32_probe --isla-preserve ieee_le32_probe \
  --isla-preserve ieee_le_quiet32_probe \
  --isla-preserve f32_rod_normal_candidate \
  --isla-preserve f32_unknown_riscv_f32Eq \
  --isla-preserve f32_unknown_riscv_f32Lt \
  --isla-preserve f32_unknown_riscv_f32Lt_quiet \
  --isla-preserve f32_unknown_riscv_f32Le \
  --isla-preserve f32_unknown_riscv_f32Le_quiet \
  --isla-preserve f32_unknown_riscv_f32Add \
  --isla-preserve f32_unknown_riscv_f32Sub \
  --isla-preserve f32_unknown_riscv_f32Mul \
  --isla-preserve f32_unknown_riscv_f32Div \
  --isla-preserve f32_unknown_riscv_f32Sqrt \
  --isla-preserve f32_unknown_riscv_f32MulAdd \
  --isla-preserve f32_unknown_riscv_f32roundToInt \
  --isla-preserve f32_unknown_riscv_f32ToI32 \
  --isla-preserve f32_unknown_riscv_f32ToUi32 \
  --isla-preserve f32_unknown_riscv_f32ToI64 \
  --isla-preserve f32_unknown_riscv_f32ToUi64 \
  --isla-preserve f32_unknown_riscv_i32ToF32 \
  --isla-preserve f32_unknown_riscv_ui32ToF32 \
  --isla-preserve f32_unknown_riscv_i64ToF32 \
  --isla-preserve f32_unknown_riscv_ui64ToF32 \
  --isla-preserve f32_unknown_riscv_f32ToF16 \
  --isla-preserve f32_unknown_riscv_f32ToF64 \
  --isla-preserve f32_unknown_riscv_f32ToBF16 \
  --isla-output-dir "$output_dir" -o f32_c f32_c.sail_project

ir="$output_dir/f32_c.ir"
rg -q '^fn zriscv_f32_to_f16_normal_rm_bits\(' "$ir"
rg -q '^fn zf32_rod_normal_candidate\(' "$ir"
for helper in \
  riscv_f32Eq riscv_f32Lt riscv_f32Lt_quiet riscv_f32Le riscv_f32Le_quiet \
  riscv_f32Add riscv_f32Sub riscv_f32Mul riscv_f32Div riscv_f32Sqrt riscv_f32MulAdd \
  riscv_f32roundToInt \
  riscv_f32ToI32 riscv_f32ToUi32 riscv_f32ToI64 riscv_f32ToUi64 \
  riscv_i32ToF32 riscv_ui32ToF32 riscv_i64ToF32 riscv_ui64ToF32 \
  riscv_f32ToF16 riscv_f32ToF64 riscv_f32ToBF16
do
  rg -q "^fn z${helper}\\(" "$ir" || {
    echo "missing SYMBOLIC function body: $helper" >&2
    exit 1
  }
  rg -q "^fn zf32_unknown_${helper}\\(" "$ir" || {
    echo "missing unknown-input probe: $helper" >&2
    exit 1
  }
done
printf 'f32 C IR bodies PASS: %s\n' "$ir"
