#!/usr/bin/env python3
"""Probe full 32-bit tuple mapping syntax before modifying the model."""

import argparse
import re
from pathlib import Path


def symbolic_mapping(source: str, name: str) -> str:
    match = re.search(rf"\$ifdef SYMBOLIC\n(val {name} : .*?)\n\$else\n", source, re.S)
    assert match, name
    return match.group(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = args.source.read_text()
    parts = [
        "default Order dec",
        "$include <prelude.sail>",
        "$include <generic_equality.sail>",
        'val strict_or_bool = pure "strict_or_bool" : (bool, bool) -> bool',
        'val strict_and_bool = pure "strict_and_bool" : (bool, bool) -> bool',
        "newtype vregidx = Vregidx : bits(5)",
        "mapping encdec_vreg : vregidx <-> bits(5) = { Vregidx(r) <-> r }",
        "enum vextfunct6 = { VEXT2_ZVF2, VEXT2_SVF2, VEXT4_ZVF4, VEXT4_SVF4, VEXT8_ZVF8, VEXT8_SVF8 }",
        symbolic_mapping(source, "encdec_nreg"),
        symbolic_mapping(source, "vext_vs1"),
        """
val vmvr_layout : (vregidx, {1, 2, 4, 8}, vregidx) <-> bits(32)

function vmvr_layout_forwards((vs2, nreg, vd)) =
  0b100111 @ 0b1 @ encdec_vreg_forwards(vs2) @ encdec_nreg_backwards(nreg) @
  0b011 @ encdec_vreg_forwards(vd) @ 0b1010111

function vmvr_layout_forwards_matches(_) = true

function vmvr_layout_backwards(word) = match
  (word[31..26], word[25..25], word[14..12], word[6..0]) {
  (0b100111, 0b1, 0b011, 0b1010111) =>
    (encdec_vreg_backwards(word[24..20]),
     encdec_nreg_forwards(word[19..15]),
     encdec_vreg_backwards(word[11..7])),
}

function vmvr_layout_backwards_matches(word) =
  strict_and_bool(
    strict_and_bool(eq_anything(word[31..26], 0b100111), eq_anything(word[25..25], 0b1)),
    strict_and_bool(
      strict_and_bool(eq_anything(word[14..12], 0b011), eq_anything(word[6..0], 0b1010111)),
      encdec_nreg_forwards_matches(word[19..15])
    )
  )

val vext_layout : (vextfunct6, bits(1), vregidx, vregidx) <-> bits(32)

function vext_layout_forwards((funct6, vm, vs2, vd)) =
  0b010010 @ vm @ encdec_vreg_forwards(vs2) @ vext_vs1_forwards(funct6) @
  0b010 @ encdec_vreg_forwards(vd) @ 0b1010111

function vext_layout_forwards_matches(_) = true

function vext_layout_backwards(word) = match
  (word[31..26], word[14..12], word[6..0]) {
  (0b010010, 0b010, 0b1010111) =>
    (vext_vs1_backwards(word[19..15]), word[25..25],
     encdec_vreg_backwards(word[24..20]), encdec_vreg_backwards(word[11..7])),
}

function vext_layout_backwards_matches(word) =
  strict_and_bool(
    strict_and_bool(eq_anything(word[31..26], 0b010010), eq_anything(word[14..12], 0b010)),
    strict_and_bool(eq_anything(word[6..0], 0b1010111),
                    vext_vs1_backwards_matches(word[19..15]))
  )

union ast = { VMVR : (vregidx, {1, 2, 4, 8}, vregidx),
              VEXT : (vextfunct6, bits(1), vregidx, vregidx), ILLEGAL : unit }

mapping old_top : ast <-> bits(32) = {
  VMVR(vs2, nreg, vd) <-> 0b100111 @ 0b1 @ encdec_vreg(vs2) @ encdec_nreg(nreg) @ 0b011 @ encdec_vreg(vd) @ 0b1010111,
  VEXT(funct6, vm, vs2, vd) <-> 0b010010 @ vm @ encdec_vreg(vs2) @ vext_vs1(funct6) @ 0b010 @ encdec_vreg(vd) @ 0b1010111,
}

mapping new_top : ast <-> bits(32) = {
  VMVR(vs2, nreg, vd) <-> vmvr_layout((vs2, nreg, vd)),
  VEXT(funct6, vm, vs2, vd) <-> vext_layout((funct6, vm, vs2, vd)),
}

function old_decode(word : bits(32)) -> ast =
  if old_top_backwards_matches(word) then old_top_backwards(word) else ILLEGAL()
function new_decode(word : bits(32)) -> ast =
  if new_top_backwards_matches(word) then new_top_backwards(word) else ILLEGAL()
function equal_decode(word : bits(32)) -> bool = eq_anything(old_decode(word), new_decode(word))

function old_vmvr_bad_funct3(nreg_bits : bits(5)) -> ast =
  old_decode(0b100111 @ 0b1 @ 0b00010 @ nreg_bits @ 0b001 @ 0b00011 @ 0b1010111)
function new_vmvr_bad_funct3(nreg_bits : bits(5)) -> ast =
  new_decode(0b100111 @ 0b1 @ 0b00010 @ nreg_bits @ 0b001 @ 0b00011 @ 0b1010111)
function old_vext_bad_funct3(vs1_bits : bits(5)) -> ast =
  old_decode(0b010010 @ 0b0 @ 0b00010 @ vs1_bits @ 0b001 @ 0b00011 @ 0b1010111)
function new_vext_bad_funct3(vs1_bits : bits(5)) -> ast =
  new_decode(0b010010 @ 0b0 @ 0b00010 @ vs1_bits @ 0b001 @ 0b00011 @ 0b1010111)

function old_encode_vmvr(nreg : {1, 2, 4, 8}) -> bits(32) =
  old_top_forwards(VMVR(Vregidx(0b00010), nreg, Vregidx(0b00011)))
function new_encode_vmvr(nreg : {1, 2, 4, 8}) -> bits(32) =
  new_top_forwards(VMVR(Vregidx(0b00010), nreg, Vregidx(0b00011)))
function old_encode_vmvr_matches(nreg : {1, 2, 4, 8}) -> bool =
  old_top_forwards_matches(VMVR(Vregidx(0b00010), nreg, Vregidx(0b00011)))
function new_encode_vmvr_matches(nreg : {1, 2, 4, 8}) -> bool =
  new_top_forwards_matches(VMVR(Vregidx(0b00010), nreg, Vregidx(0b00011)))
function equal_raw_nreg(nreg : {1, 2, 4, 8}) -> bool =
  old_encode_vmvr(nreg) == new_encode_vmvr(nreg)
""",
    ]
    for nreg in (1, 2, 4, 8):
        parts.append(f"function expect_vmvr_{nreg}(word : bits(32)) -> bool = "
                     f"eq_anything(new_decode(word), VMVR(Vregidx(0b00010), {nreg}, Vregidx(0b00011)))")
    for member in ("VEXT2_ZVF2", "VEXT2_SVF2", "VEXT4_ZVF4",
                   "VEXT4_SVF4", "VEXT8_ZVF8", "VEXT8_SVF8"):
        parts.append(f"function expect_vext_{member}(word : bits(32)) -> bool = "
                     f"eq_anything(new_decode(word), VEXT({member}, word[25..25], Vregidx(0b00010), Vregidx(0b00011)))")
    args.output.write_text("\n\n".join(parts))


if __name__ == "__main__":
    main()
