#!/usr/bin/env python3
"""Ensure the selected pure helpers compile to generic equality calls."""

from pathlib import Path
import re
import sys

ir = Path(sys.argv[1]).read_text()
names = (
    "fp_min_pure", "fp_max_pure", "fp_gt_pure", "fp_ge_pure",
    "fp_class_onehot_pure", "ieee_is_nan",
    "riscv_f16ToI16_pure", "riscv_f16ToI8_pure", "riscv_f32ToI16_pure",
    "riscv_f16ToUi16_pure", "riscv_f16ToUi8_pure", "riscv_f32ToUi16_pure",
)
for name in names:
    match = re.search(rf"^fn z{name}\([^\n]*", ir, re.M)
    assert match, f"missing IR function {name}"
    next_fn = re.search(r"^fn ", ir[match.end():], re.M)
    body = ir[match.start():match.end() + next_fn.start()] if next_fn else ir[match.start():]
    assert "zeq_bits" not in body and "zneq_bits" not in body, f"{name}: specialized bit equality in pure body"
assert '"eq_anything"' in ir, "generic equality primop missing"
print(f"validated {len(names)} pure IR functions")
