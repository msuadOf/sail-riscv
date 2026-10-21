#!/usr/bin/env python3
"""Guard the 12 selected SYMBOLIC clauses against mask-control-flow regressions."""

import pathlib
import re

MODEL = pathlib.Path(__file__).resolve().parents[3] / "model/extensions/V"
CLAUSES = {
    "vext_fp_insts.sail": (
        "FVVTYPE", "FVVMATYPE", "FWVVTYPE", "FWVVMATYPE", "FWVTYPE",
        "FVFTYPE", "FVFMATYPE", "FWVFTYPE", "FWVFMATYPE", "FWFTYPE",
    ),
    "vext_fp_vm_insts.sail": ("FVVMTYPE", "FVFMTYPE"),
}

for file, names in CLAUSES.items():
    source = (MODEL / file).read_text()
    for name in names:
        match = re.search(rf"^function clause execute {name}\([^\n]*", source, re.M)
        assert match, f"missing {name}"
        begin = source.rfind("$ifdef SYMBOLIC", 0, match.start())
        assert begin >= 0, f"{name}: missing SYMBOLIC clause"
        lane = source[match.start():source.index("$else", match.start())]
        if name == "FVFTYPE":
            assert "VF_VSLIDE1UP | funct6 == VF_VSLIDE1DOWN" in lane
            lane = lane.split("  } else {", 1)[1]
        assert not re.search(r"if\s+mask\[i\]", lane), f"{name}: mask forks in SYMBOLIC loop"
        assert "accrue_fflags" in lane, f"{name}: flags not accumulated"

print("12 SYMBOLIC lane clauses have no per-lane mask branch")
