#!/usr/bin/env python3
"""Guard the approved conversion and sqrt/class SYMBOLIC loops."""

from pathlib import Path

root = Path(__file__).resolve().parents[3] / "model/extensions/V"
source = (root / "vext_fp_insts.sail").read_text()
for name in ("VFUNARY0", "VFWUNARY0", "VFNUNARY0", "VFUNARY1"):
    marker = f"function clause execute {name}("
    before, after = source.split(marker, 1)
    assert before.rstrip().endswith("$ifdef SYMBOLIC"), f"{name}: missing SYMBOLIC body"
    symbolic = after.split("$else", 1)[0]
    assert "vector_select_masked" in symbolic, f"{name}: missing data merge"
    assert "accrue_fflags" in symbolic, f"{name}: missing aggregate flags"
utils = (root / "vext_fp_utils_insts.sail").read_text()
assert "fp_class_onehot_pure" in utils
print("four unary SYMBOLIC loops and pure class helper present")
