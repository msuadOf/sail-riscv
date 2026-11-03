// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

function fsplit_BF16 (v : bits(16)) -> (bits(1), bits(8), bits(7)) = (v[15..15], v[14..7], v[6..0])

function fmake_BF16 (sign : bits(1), exp : bits(8), mant : bits(7)) -> (bits(16)) = (sign @ exp @ mant)

$ifdef SYMBOLIC
function bf16_to_f32 (v : bits(16)) -> (bits_fflags, bits(32)) = {
  let (sign, exp, mant) = fsplit_BF16(v);
  let is_nan = strict_and_bool(eq_anything(exp, ones()), not_bool(eq_anything(mant, zeros())));
  let is_snan = strict_and_bool(is_nan, eq_anything(mant[6], 0b0));
  if is_nan then {
    if is_snan then (nvFlag(), canonical_NaN_S())
    else (zeros(), canonical_NaN_S())
  } else (zeros(), v @ zeros(16))
}
$else
function bf16_to_f32 (v : bits(16)) -> (bits_fflags, bits(32)) = {
  let (sign, exp, mant) = fsplit_BF16(v);
  let is_nan = exp == ones() & mant != zeros();
  let is_inf = exp == ones() & mant == zeros();

  let fflags = if is_nan & signed(mant) >= 0 then nvFlag() else zeros();
  let value =
    if is_nan then canonical_NaN_S()
    else if is_inf then fmake_S(sign, ones(), zeros())
    else fmake_S(sign, exp, mant @ zeros(16));

  (fflags, value)
}
$endif

function bf16_to_f32_set_flags(nval : bits(16)) -> bits(32) = {
  let (fflags, wval) = bf16_to_f32(nval);
  accrue_fflags(fflags);
  wval
}
