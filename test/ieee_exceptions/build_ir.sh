#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="${1:?usage: bash build_ir.sh OUTPUT_DIR ISLA_PLUGIN}"
isla_plugin="${2:?usage: bash build_ir.sh OUTPUT_DIR ISLA_PLUGIN}"
mkdir -p "$output_dir"

cd "$test_dir"
mapfile -t probes < <(rg --only-matching --replace '$1' 'function (ieee_[a-z0-9_]+_probe)\(' ieee_exceptions.sail)
preserve_args=()
for probe in "${probes[@]}"; do
  preserve_args+=(--isla-preserve "$probe")
done

sail --strict-var --strict-bitvector --strict-exponentials --require-version 0.20.1 \
  --memo-z3-path "$output_dir/sail_smt_cache" -D SYMBOLIC --all-modules \
  --just-check ieee_exceptions.sail_project
sail -plugin "$isla_plugin" -isla "${preserve_args[@]}" \
  --strict-var --strict-bitvector --strict-exponentials --require-version 0.20.1 \
  --memo-z3-path "$output_dir/sail_smt_cache" --all-modules \
  --isla-output-dir "$output_dir" -o ieee_exceptions ieee_exceptions.sail_project

actual="$(rg -c '^fn zieee_.*_probe\(' "$output_dir/ieee_exceptions.ir")"
if [[ "$actual" != "${#probes[@]}" ]]; then
  printf 'IR probe count mismatch: expected %s, found %s\n' "${#probes[@]}" "$actual" >&2
  exit 1
fi
printf 'IEEE exception IR: %s (%s preserved probes)\n' "$output_dir/ieee_exceptions.ir" "$actual"
