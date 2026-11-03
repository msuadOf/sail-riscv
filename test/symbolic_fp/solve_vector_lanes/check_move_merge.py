#!/usr/bin/env python3
"""Guard the two authorized move/merge SYMBOLIC clauses against data forks."""

from pathlib import Path
import re

source = (Path(__file__).resolve().parents[3] / "model/extensions/V/vext_fp_insts.sail").read_text()
for name in ("VFMV", "VFMERGE"):
    section = source.split(f"function clause execute {name}(", 1)[1]
    prefix = source[:source.index(f"function clause execute {name}(")]
    assert prefix.rstrip().endswith("$ifdef SYMBOLIC"), f"{name}: no SYMBOLIC implementation"
    symbolic = section.split("$else", 1)[0]
    assert not re.search(r"if\s+(?:mask|vm_val)\[i\]", symbolic), f"{name}: lane data forks"
    assert "vector_select_masked" in symbolic, f"{name}: no vector selection"
print("VFMV/VFMERGE SYMBOLIC mask selection present")
