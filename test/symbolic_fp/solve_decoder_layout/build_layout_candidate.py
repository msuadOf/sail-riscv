#!/usr/bin/env python3
"""Render the reviewable SYMBOLIC-only outer mapping candidate off-tree."""

import argparse
import re
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = args.source.read_text()
    fixture = args.fixture.read_text()
    vmvr_helper = fixture[fixture.index("val vmvr_layout :"):fixture.index("val vext_layout :")].rstrip()
    vext_helper = fixture[fixture.index("val vext_layout :"):fixture.index("union ast =")].rstrip()
    for ctor, original_rhs, new_rhs in (
        ("VMVRTYPE", "0b100111 @ 0b1 @ encdec_vreg(vs2) @ encdec_nreg(nreg) @ 0b011 @ encdec_vreg(vd) @ 0b1010111", "vmvr_layout((vs2, nreg, vd))"),
        ("VEXTTYPE", "0b010010 @ vm @ encdec_vreg(vs2) @ vext_vs1(funct6) @ 0b010 @ encdec_vreg(vd) @ 0b1010111", "vext_layout((funct6, vm, vs2, vd))"),
    ):
        pattern = rf"mapping clause encdec = {ctor}\([^\n]*\)\n  <-> [^\n]*\n  when [^\n]*\n     \| [^\n]*"
        matches = list(re.finditer(pattern, source))
        assert len(matches) == 1, ctor
        old = matches[0].group()
        assert old.count(original_rhs) == 1
        new = old.replace(original_rhs, new_rhs)
        source = source.replace(old, "$ifdef SYMBOLIC\n" + new + "\n$else\n" + old + "\n$endif", 1)
    for ctor, block in (("VMVRTYPE", vmvr_helper), ("VEXTTYPE", vext_helper)):
        anchor = f"$ifdef SYMBOLIC\nmapping clause encdec = {ctor}"
        assert source.count(anchor) == 1
        source = source.replace(anchor, "$ifdef SYMBOLIC\n" + block + "\n$endif\n\n" + anchor, 1)
    args.output.write_text(source)


if __name__ == "__main__":
    main()
