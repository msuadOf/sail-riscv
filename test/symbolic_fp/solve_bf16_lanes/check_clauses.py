#!/usr/bin/env python3
"""Check that the four BF16 symbolic loops select lanes as values."""

from pathlib import Path
import re

MODEL = Path(__file__).resolve().parents[3] / "model/extensions/bfloat16"
CLAUSES = {
    "zvfbfmin_insts.sail": ("VFNCVTBF16_F_F_W", "VFWCVTBF16_F_F_V"),
    "zvfbfwma_insts.sail": ("VFWMACCBF16_VV", "VFWMACCBF16_VF"),
}

conversion = (MODEL / "zfbfmin_utils.sail").read_text()
assert "$ifdef SYMBOLIC" in conversion.split("function bf16_to_f32_set_flags")[0]

for file, names in CLAUSES.items():
    source = (MODEL / file).read_text()
    for name in names:
        match = re.search(rf"^function clause execute\s*\(?{name}\(", source, re.M)
        assert match, f"missing {name}"
        start = source.rfind("$ifdef SYMBOLIC", 0, match.start())
        assert start >= 0, f"{name}: missing SYMBOLIC clause"
        body = source[start:source.index("\nmapping clause assembly", match.end())]
        lane = body.split("$else", 1)[0]
        assert not re.search(r"if\s+mask\[i\]", lane), f"{name}: mask fork"
        assert "vector_select_masked" in lane, f"{name}: masked result selection"
        assert lane.count("accrue_fflags") == 1, f"{name}: expected one flags update"

print("BF16 SYMBOLIC conversion and four lane loops present")
