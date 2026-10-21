#!/usr/bin/env python3
"""Extract both mapping implementations into one small Sail decoder probe."""

import argparse
import re
from pathlib import Path


def old_block(source: str, name: str) -> str:
    match = re.search(rf"mapping {name} : .*?\n}}", source, re.S)
    assert match, name
    return match.group().replace(f"mapping {name} :", f"mapping old_{name} :")


def new_block(source: str, name: str) -> str:
    match = re.search(rf"\$ifdef SYMBOLIC\n(val {name} : .*?)\n\$else\n", source, re.S)
    assert match, name
    return re.sub(rf"\b{name}(?=_|\b)", f"new_{name}", match.group(1))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    before = args.before.read_text()
    after = args.after.read_text()
    parts = [
        "default Order dec",
        "$include <prelude.sail>",
        "$include <generic_equality.sail>",
        'val strict_or_bool = pure "strict_or_bool" : (bool, bool) -> bool',
        'val strict_and_bool = pure "strict_and_bool" : (bool, bool) -> bool',
        "enum vextfunct6 = { VEXT2_ZVF2, VEXT2_SVF2, VEXT4_ZVF4, VEXT4_SVF4, VEXT8_ZVF8, VEXT8_SVF8 }",
    ]
    for name in ("encdec_nreg", "vext_vs1"):
        parts.extend((old_block(before, name), new_block(after, name)))
    parts.append("""
union ast = { VMVR : (bits(5), {1, 2, 4, 8}, bits(5)), VEXT : (vextfunct6, bits(1), bits(5), bits(5)), ILLEGAL : unit }

mapping old_top : ast <-> bits(32) = {
  VMVR(vs2, nreg, vd) <-> 0b100111 @ 0b1 @ vs2 @ old_encdec_nreg(nreg) @ 0b011 @ vd @ 0b1010111,
  VEXT(funct6, vm, vs2, vd) <-> 0b010010 @ vm @ vs2 @ old_vext_vs1(funct6) @ 0b010 @ vd @ 0b1010111,
}
mapping new_top : ast <-> bits(32) = {
  VMVR(vs2, nreg, vd) <-> 0b100111 @ 0b1 @ vs2 @ new_encdec_nreg(nreg) @ 0b011 @ vd @ 0b1010111,
  VEXT(funct6, vm, vs2, vd) <-> 0b010010 @ vm @ vs2 @ new_vext_vs1(funct6) @ 0b010 @ vd @ 0b1010111,
}
function old_decode(word : bits(32)) -> ast =
  if old_top_backwards_matches(word) then old_top_backwards(word) else ILLEGAL()
function new_decode(word : bits(32)) -> ast =
  if new_top_backwards_matches(word) then new_top_backwards(word) else ILLEGAL()

union neighbor = { N16 : bits(10), N_BAD : unit }
mapping old_neighbor : neighbor <-> bits(16) = {
  N16(payload) <-> 0b101011 @ payload,
}
mapping new_neighbor : neighbor <-> bits(16) = {
  N16(payload) <-> 0b101011 @ payload,
}
function old_decode16(word : bits(16)) -> neighbor =
  if old_neighbor_backwards_matches(word) then old_neighbor_backwards(word) else N_BAD()
function new_decode16(word : bits(16)) -> neighbor =
  if new_neighbor_backwards_matches(word) then new_neighbor_backwards(word) else N_BAD()

function equal_nreg_matches(word : bits(5)) -> bool =
  { let old = old_encdec_nreg_forwards_matches(word);
    let new = new_encdec_nreg_forwards_matches(word);
    strict_or_bool(strict_and_bool(old, new), strict_and_bool(not_bool(old), not_bool(new))) }
function equal_vext_matches(word : bits(5)) -> bool =
  { let old = old_vext_vs1_backwards_matches(word);
    let new = new_vext_vs1_backwards_matches(word);
    strict_or_bool(strict_and_bool(old, new), strict_and_bool(not_bool(old), not_bool(new))) }
function equal_decode(word : bits(32)) -> bool = eq_anything(old_decode(word), new_decode(word))
function equal_decode16(word : bits(16)) -> bool = eq_anything(old_decode16(word), new_decode16(word))
""")
    for bits in ("0b00000", "0b00001", "0b00011", "0b00111"):
        parts.append(f"function nreg_roundtrip_{bits[2:]}() -> bits(5) = "
                     f"new_encdec_nreg_backwards(new_encdec_nreg_forwards({bits}))")
    for member in ("VEXT2_ZVF2", "VEXT2_SVF2", "VEXT4_ZVF4", "VEXT4_SVF4", "VEXT8_ZVF8", "VEXT8_SVF8"):
        parts.append(f"function vext_roundtrip_{member}() -> vextfunct6 = "
                     f"new_vext_vs1_backwards(new_vext_vs1_forwards({member}))")
    args.output.write_text("\n\n".join(parts))


if __name__ == "__main__":
    main()
