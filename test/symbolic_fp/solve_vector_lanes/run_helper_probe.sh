#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="${1:?usage: run_helper_probe.sh OUTPUT_DIR ISLA_PLUGIN RUNNER}"
isla_plugin="${2:?usage: run_helper_probe.sh OUTPUT_DIR ISLA_PLUGIN RUNNER}"
runner="${3:?usage: run_helper_probe.sh OUTPUT_DIR ISLA_PLUGIN RUNNER}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
python3 "$test_dir/build_helper_probe.py" "$output_dir"

names=(eq_min_unknown eq_max_unknown eq_gt_unknown eq_ge_unknown
       new_min_unknown new_max_unknown new_gt_unknown new_ge_unknown
       eq_directed_cases)
for width in 32 64; do
  for op in min max gt ge; do
    names+=("eq_${op}_unknown${width}" "new_${op}_unknown${width}")
  done
done
for width in 16 32 64; do
  names+=("eq_class_unknown${width}" "new_class_unknown${width}"
          "eq_class_onehot${width}" "eq_class_directed${width}")
done
for op in riscv_f16ToI16 riscv_f16ToI8 riscv_f32ToI16 \
          riscv_f16ToUi16 riscv_f16ToUi8 riscv_f32ToUi16; do
  names+=("eq_${op}_unknown" "new_${op}_unknown")
done
printf '%s\n' "${names[@]}" > "$output_dir/names.txt"

preserve=()
for name in "${names[@]}"; do preserve+=(--isla-preserve "$name"); done
(
  cd "$output_dir"
  sail -plugin "$isla_plugin" -isla -D SYMBOLIC --strict-var \
    --strict-bitvector --strict-exponentials --require-version 0.20.1 \
    --all-modules "${preserve[@]}" --isla-output-dir "$output_dir" \
    -o helper_probe helper_probe.sail_project
)
"$runner" "$output_dir/helper_probe.ir" "$output_dir/names.txt" \
  > "$output_dir/run.log" 2>&1
python3 "$test_dir/validate_probe_log.py" "$output_dir/names.txt" "$output_dir/run.log"
python3 "$test_dir/check_pure_ir.py" "$output_dir/helper_probe.ir"
cat "$output_dir/run.log"
sha256sum "$output_dir/helper_probe.sail" "$output_dir/helper_probe.ir" \
  "$runner" "$output_dir/run.log" "$test_dir/build_helper_probe.py" \
  "$test_dir/runner.rs" "$isla_plugin" \
  "$output_dir/model/prelude/prelude.sail" \
  "$output_dir/model/prelude/ieee_fp_primops.sail" \
  "$output_dir/model/core/softfloat_interface.sail" \
  "$output_dir/model/core/float_classify.sail" \
  "$output_dir/model/core/ieee_fp_exceptions.sail" \
  "$output_dir/model/extensions/FD/softfloat_symbolic.sail" \
  "$output_dir/model/extensions/FD/softfloat_symbolic_f16.sail" \
  "$output_dir/model/extensions/FD/softfloat_symbolic_f32.sail" \
  "$output_dir/model/extensions/FD/softfloat_symbolic_f64.sail" \
  > "$output_dir/hashes.txt"
