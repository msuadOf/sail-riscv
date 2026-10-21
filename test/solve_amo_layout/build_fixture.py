#!/usr/bin/env python3
"""Build one IR fixture containing the original and proposed AMO layouts."""

import argparse
from pathlib import Path


OPS = (
    ("AMOSWAP", "00001"), ("AMOADD", "00000"), ("AMOXOR", "00100"),
    ("AMOAND", "01100"), ("AMOOR", "01000"), ("AMOMIN", "10000"),
    ("AMOMAX", "10100"), ("AMOMINU", "11000"), ("AMOMAXU", "11100"),
    ("AMOCAS", "00101"),
)


def fixture(source: str, e_mode: bool) -> str:
    start = source.index("val amo_layout :")
    end = source.index("$endif", start)
    layout = source[start:end].strip()
    op_start = source.index("mapping encdec_amoop :")
    op_mapping = source[op_start:source.index("$ifdef SYMBOLIC", op_start)].strip()
    width_mapping = "mapping width_enc_wide : word_width_wide <-> bits(3) = { 1 <-> 0b000, 2 <-> 0b001, 4 <-> 0b010, 8 <-> 0b011, 16 <-> 0b100 }"
    reg_width = 4 if e_mode else 5
    return f"""default Order dec
$include <prelude.sail>
$include <generic_equality.sail>
val strict_or_bool = pure "strict_or_bool" : (bool, bool) -> bool
val strict_and_bool = pure "strict_and_bool" : (bool, bool) -> bool
let base_E_enabled = {'true' if e_mode else 'false'}
let regidx_bit_width = {reg_width}
newtype regidx = Regidx : bits({reg_width})
mapping encdec_reg : regidx <-> bits(5) = {{
  forwards Regidx(r) => {'0b0 @ r' if e_mode else 'r'},
  backwards r if base_E_enabled == false | r[4] == 0b0 => Regidx(r[regidx_bit_width - 1 .. 0]),
}}
mapping bool_bit : bool <-> bits(1) = {{ false <-> 0b0, true <-> 0b1 }}
type word_width_wide = {{1, 2, 4, 8, 16}}
{width_mapping}
enum amoop = {{ {', '.join(name for name, _ in OPS)} }}
{op_mapping}
{layout}
union ast = {{ AMO : (amoop, bool, bool, regidx, regidx, word_width_wide, regidx), OTHER : unit }}
mapping old_top : ast <-> bits(32) = {{
  AMO(op, aq, rl, rs2, rs1, size, rd) <-> encdec_amoop(op) @ bool_bit(aq) @ bool_bit(rl) @ encdec_reg(rs2) @ encdec_reg(rs1) @ width_enc_wide(size) @ encdec_reg(rd) @ 0b0101111,
}}
mapping new_top : ast <-> bits(32) = {{
  AMO(op, aq, rl, rs2, rs1, size, rd) <-> amo_layout((op, aq, rl, rs2, rs1, size, rd)),
}}
function fixture_guard(size : word_width_wide, op : amoop, rs2 : regidx, rd : regidx) -> bool = {{
  if op == AMOCAS & size == 16 &
     (rs2 == Regidx(0b{'0011' if e_mode else '00011'}) | rd == Regidx(0b{'0011' if e_mode else '00011'}))
  then assert(false);
  size != 1
}}
mapping old_guarded : ast <-> bits(32) = {{
  AMO(op, aq, rl, rs2, rs1, size, rd) <-> encdec_amoop(op) @ bool_bit(aq) @ bool_bit(rl) @ encdec_reg(rs2) @ encdec_reg(rs1) @ width_enc_wide(size) @ encdec_reg(rd) @ 0b0101111
  when fixture_guard(size, op, rs2, rd),
}}
mapping new_guarded : ast <-> bits(32) = {{
  AMO(op, aq, rl, rs2, rs1, size, rd) <-> amo_layout((op, aq, rl, rs2, rs1, size, rd))
  when fixture_guard(size, op, rs2, rd),
}}
function old_guarded_matches(word : bits(32)) -> bool = old_guarded_backwards_matches(word)
function new_guarded_matches(word : bits(32)) -> bool = new_guarded_backwards_matches(word)
function old_guarded_forward(size : word_width_wide) -> bits(32) =
  old_guarded_forwards(AMO(AMOCAS, true, false, Regidx(0b{'0011' if e_mode else '00011'}), Regidx(0b{'0010' if e_mode else '00010'}), size, Regidx(0b{'0001' if e_mode else '00001'})))
function new_guarded_forward(size : word_width_wide) -> bits(32) =
  new_guarded_forwards(AMO(AMOCAS, true, false, Regidx(0b{'0011' if e_mode else '00011'}), Regidx(0b{'0010' if e_mode else '00010'}), size, Regidx(0b{'0001' if e_mode else '00001'})))
function equal_guarded_forward(size : word_width_wide) -> bool =
  old_guarded_forward(size) == new_guarded_forward(size)
function old_decode(word : bits(32)) -> ast = if old_top_backwards_matches(word) then old_top_backwards(word) else OTHER()
function new_decode(word : bits(32)) -> ast = if new_top_backwards_matches(word) then new_top_backwards(word) else OTHER()
function equal_matches(word : bits(32)) -> bool = old_top_backwards_matches(word) == new_top_backwards_matches(word)
function equal_decode(word : bits(32)) -> bool = eq_anything(old_decode(word), new_decode(word))
function equal_encode(a : ast) -> bool = if old_top_forwards_matches(a) & new_top_forwards_matches(a) then old_top_forwards(a) == new_top_forwards(a) else true
function equal_forward_matches(a : ast) -> bool = old_top_forwards_matches(a) == new_top_forwards_matches(a)
function equal_roundtrip(word : bits(32)) -> bool =
  if old_top_backwards_matches(word) then
    old_top_forwards(old_top_backwards(word)) == new_top_forwards(new_top_backwards(word))
  else true
function forward_matches_from_word(word : bits(32)) -> bool =
  if old_top_backwards_matches(word) then
    old_top_forwards_matches(old_top_backwards(word)) & new_top_forwards_matches(new_top_backwards(word))
  else true
function other_forward_matches() -> bool =
  old_top_forwards_matches(OTHER()) == new_top_forwards_matches(OTHER())
function old_size_matches(size : word_width_wide) -> bool =
  old_top_forwards_matches(AMO(AMOCAS, true, false, Regidx(0b{'0011' if e_mode else '00011'}), Regidx(0b{'0010' if e_mode else '00010'}), size, Regidx(0b{'0001' if e_mode else '00001'})))
function new_size_matches(size : word_width_wide) -> bool =
  new_top_forwards_matches(AMO(AMOCAS, true, false, Regidx(0b{'0011' if e_mode else '00011'}), Regidx(0b{'0010' if e_mode else '00010'}), size, Regidx(0b{'0001' if e_mode else '00001'})))
function old_size_encode(size : word_width_wide) -> bits(32) =
  old_top_forwards(AMO(AMOCAS, true, false, Regidx(0b{'0011' if e_mode else '00011'}), Regidx(0b{'0010' if e_mode else '00010'}), size, Regidx(0b{'0001' if e_mode else '00001'})))
function new_size_encode(size : word_width_wide) -> bits(32) =
  new_top_forwards(AMO(AMOCAS, true, false, Regidx(0b{'0011' if e_mode else '00011'}), Regidx(0b{'0010' if e_mode else '00010'}), size, Regidx(0b{'0001' if e_mode else '00001'})))
function equal_size_encode(size : word_width_wide) -> bool = old_size_encode(size) == new_size_encode(size)
function equal_size_matches(size : word_width_wide) -> bool = old_size_matches(size) == new_size_matches(size)
function make_amo(word : bits(32)) -> ast = new_decode(word)
function old_encode(a : ast) -> bits(32) = old_top_forwards(a)
function new_encode(a : ast) -> bits(32) = new_top_forwards(a)
function amo_membership(word : bits(32)) -> bool = amo_layout_backwards_matches(word)
function amo_value(word : bits(32)) -> (amoop, bool, bool, regidx, regidx, word_width_wide, regidx) = amo_layout_backwards(word)
function opcode_fatal_negative(word : bits(32)) -> bool =
  if new_top_backwards_matches(word) then {{
    let (op, _, _, rs2, _, size, rd) = amo_layout_backwards(word);
    if op == AMOCAS & size == 16 & (rs2 == Regidx(0b{'0011' if e_mode else '00011'}) | rd == Regidx(0b{'0011' if e_mode else '00011'})) then assert(false);
    true
  }} else false
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--e-mode", action="store_true")
    args = parser.parse_args()
    args.output.write_text(fixture(args.source.read_text(), args.e_mode))


if __name__ == "__main__":
    main()
