#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="${1:?usage: check_stage_b.sh OUTPUT_DIR ISLA_PLUGIN}"
isla_plugin="${2:?usage: check_stage_b.sh OUTPUT_DIR ISLA_PLUGIN}"
mkdir -p "$output_dir"

cd "$test_dir"
sail --strict-var --strict-bitvector --strict-exponentials --require-version 0.20.1 \
  --memo-z3-path "$output_dir/sail_smt_cache" -D SYMBOLIC --all-modules \
  --just-check stage_b.sail_project
sail -plugin "$isla_plugin" -isla --strict-var --strict-bitvector \
  --strict-exponentials --require-version 0.20.1 \
  --memo-z3-path "$output_dir/sail_smt_cache" --all-modules \
  --isla-preserve stage_b_unknown_eq_inputs \
  --isla-preserve stage_b_unknown_add_inputs \
  --isla-output-dir "$output_dir" -o stage_b stage_b.sail_project

ir="$output_dir/stage_b.ir"
rg -q '^val zriscv_f32Eq ' "$ir"
rg -q '^fn zriscv_f32Eq\(' "$ir"
rg -q '^fn zriscv_valid_rm_to_ieee\(' "$ir"
case "${STAGE_B_PHASE:-integrated}" in
  pre_c)
    # Historical B gate: production Add could not have a partial flags body.
    if rg -q '^fn zriscv_f32Add\(' "$ir"; then
      echo 'production addition body entered the pre-C stage B IR' >&2
      exit 1
    fi
    ;;
  integrated)
    # C may now provide a complete Add body. The B demo remains a separate name.
    ;;
  *)
    echo 'STAGE_B_PHASE must be pre_c or integrated' >&2
    exit 2
    ;;
esac
rg -q '^fn zdemo_f32_add_bits\(' "$ir"
rg -q '^fn zstage_b_bf16_interface_bits\(' "$ir"
rg -q '^fn zstage_b_unknown_eq\(' "$ir"
rg -q '^fn zstage_b_unknown_eq_inputs\(' "$ir"
rg -q '^fn zstage_b_unknown_add_inputs\(' "$ir"
rg -q '^fn zisla_footprint\(' "$ir"
rg -q '"fp_eq"' "$ir"
rg -q '"fp_add"' "$ir"
rg -q '"fp32_to_ieee"' "$ir"
rg -q '"fp32_from_ieee"' "$ir"
rg -q '"fp32_to_bf16"' "$ir"

sail --strict-var --strict-bitvector --strict-exponentials \
  --require-version 0.20.1 --memo-z3-path "$output_dir/sail_smt_cache" \
  --all-modules --cpp --c-no-main --c-preserve stage_b_cpp_probe \
  -o "$output_dir/stage_b_cpp" stage_b.sail_project
rg -q 'softfloat_f32eq\(' "$output_dir/stage_b_cpp.cpp"
printf 'stage B IR structure PASS: %s\n' "$ir"
