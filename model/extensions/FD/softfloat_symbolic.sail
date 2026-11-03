// =======================================================================================
// This Sail RISC-V architecture model is subject to the BSD two-clause license.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================
// The original val declarations retain the C++ and Lem SoftFloat backends.
// This file holds common pure helpers. Per-format function bodies live in
// softfloat_symbolic_f16/f32/f64.sail.


function riscv_pack_ieee_flags(e : ieee_fp_exceptions) -> bits_fflags = {
  let shared = ieee_pack_shared_flags(e);
  shared[0] @ shared[1] @ shared[2] @ shared[3] @ shared[4]
}

function riscv_canonical_nan16() -> bits(16) = 0x7e00
function riscv_canonical_nan32() -> bits(32) = 0x7fc00000
function riscv_canonical_nan64() -> bits(64) = 0x7ff8000000000000
function riscv_canonical_nan_bf16() -> bits(16) = 0x7fc0

// Precondition: architectural legality checks have resolved dynamic frm and
// supplied one of 0..4. ROD=6 is handled only by the two narrowing wrappers.
function riscv_valid_rm_to_ieee(rm : bits_rm) -> float_rounding_mode =
  ite(rm == 0b000, round_nearest_ties_to_even(),
  ite(rm == 0b001, round_toward_zero(),
  ite(rm == 0b010, round_toward_negative(),
  ite(rm == 0b011, round_toward_positive(), round_nearest_ties_to_away()))))

