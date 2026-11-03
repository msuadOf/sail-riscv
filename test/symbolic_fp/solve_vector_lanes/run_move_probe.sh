#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="${1:?usage: run_move_probe.sh OUTPUT_DIR ISLA_PLUGIN RUNNER}"
isla_plugin="${2:?usage: run_move_probe.sh OUTPUT_DIR ISLA_PLUGIN RUNNER}"
runner="${3:?usage: run_move_probe.sh OUTPUT_DIR ISLA_PLUGIN RUNNER}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
names=(probe_old_move probe_new_move eq_move
       probe_old_merge probe_new_merge eq_merge
       eq_merge_vl0 new_merge_vl0
       eq_merge_prestart new_merge_prestart
       eq_merge_fractional new_merge_fractional
       eq_merge_full new_merge_full)
printf '%s\n' "${names[@]}" > "$output_dir/move_names.txt"
preserve=()
for name in "${names[@]}"; do preserve+=(--isla-preserve "$name"); done
(
  cd "$test_dir"
  sail -plugin "$isla_plugin" -isla -D SYMBOLIC --strict-var \
    --strict-bitvector --strict-exponentials --require-version 0.20.1 \
    --all-modules "${preserve[@]}" --isla-output-dir "$output_dir" \
    -o move_probe move_probe.sail_project
)
"$runner" "$output_dir/move_probe.ir" "$output_dir/move_names.txt" \
  > "$output_dir/move_run.log" 2>&1
python3 "$test_dir/validate_probe_log.py" "$output_dir/move_names.txt" "$output_dir/move_run.log"
cat "$output_dir/move_run.log"
sha256sum "$test_dir/move_probe.sail" "$output_dir/move_probe.ir" \
  "$runner" "$output_dir/move_run.log" > "$output_dir/move_hashes.txt"
