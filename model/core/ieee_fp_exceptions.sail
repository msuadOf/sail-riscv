// =======================================================================================
// This Sail RISC-V architecture model is subject to the BSD two-clause license.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================
// IEEE exception facts for pure operations. ISA flag positions are assigned
// by the architecture wrapper, never by this shared model code.


struct ieee_fp_exceptions = {
  invalid        : bool,
  divide_by_zero : bool,
  overflow       : bool,
  underflow      : bool,
  inexact        : bool,
}

// Decompose through Sail's shared float_bits type. Keep Boolean operations
// strict so symbolic input bits do not fork on classification. Generic
// equality builds a Boolean term without eager bitvector solver queries.
val ieee_is_nan : forall 'n, is_fp_bits('n). bits('n) -> bool
function ieee_is_nan(raw) = {
  let fp : float_bits('n) = float_decompose(raw);
  strict_and_bool(eq_anything(fp.exp, sail_ones(length(fp.exp))), not_bool(eq_anything(fp.mantissa, sail_zeros(length(fp.mantissa)))))
}

val ieee_is_snan : forall 'n, is_fp_bits('n). bits('n) -> bool
function ieee_is_snan(raw) = {
  let fp : float_bits('n) = float_decompose(raw);
  strict_and_bool(ieee_is_nan(raw), eq_anything(fp.mantissa[length(fp.mantissa) - 1], bitzero))
}

val ieee_is_inf : forall 'n, is_fp_bits('n). bits('n) -> bool
function ieee_is_inf(raw) = {
  let fp : float_bits('n) = float_decompose(raw);
  strict_and_bool(eq_anything(fp.exp, sail_ones(length(fp.exp))), eq_anything(fp.mantissa, sail_zeros(length(fp.mantissa))))
}

val ieee_is_zero : forall 'n, is_fp_bits('n). bits('n) -> bool
function ieee_is_zero(raw) = {
  let fp : float_bits('n) = float_decompose(raw);
  strict_and_bool(eq_anything(fp.exp, sail_zeros(length(fp.exp))), eq_anything(fp.mantissa, sail_zeros(length(fp.mantissa))))
}

val ieee_is_finite : forall 'n, is_fp_bits('n). bits('n) -> bool
function ieee_is_finite(raw) = {
  let fp : float_bits('n) = float_decompose(raw);
  not_bool(eq_anything(fp.exp, sail_ones(length(fp.exp))))
}

// NaN 类别决定当前操作数是否产生 invalid；各源分别求值后再合并。
val ieee_operand_invalid : forall 'n, is_fp_bits('n). (bool, bits('n)) -> bool
function ieee_operand_invalid(signaling, raw) =
  if ieee_is_nan(raw) then {
    if ieee_is_snan(raw) then true else signaling
  } else false

// Shared Sail flag order is NV bit 0, DZ bit 1, OF bit 2, UF bit 3, NX bit 4.
// The architecture wrapper alone reverses these facts into RISC-V fflags.
function ieee_exception_facts(invalid : bool, divide_by_zero : bool, overflow : bool, underflow : bool, inexact : bool) -> ieee_fp_exceptions =
  struct {
    invalid = invalid,
    divide_by_zero = divide_by_zero,
    overflow = overflow,
    underflow = underflow,
    inexact = inexact,
  }

function ieee_has_invalid(flags : ieee_fp_exceptions) -> bool = flags.invalid
function ieee_has_divide_by_zero(flags : ieee_fp_exceptions) -> bool = flags.divide_by_zero
function ieee_has_overflow(flags : ieee_fp_exceptions) -> bool = flags.overflow
function ieee_has_underflow(flags : ieee_fp_exceptions) -> bool = flags.underflow
function ieee_has_inexact(flags : ieee_fp_exceptions) -> bool = flags.inexact

// Convert internal IEEE facts to Sail's shared NV0..NX4 flag type at the boundary.
function ieee_pack_shared_flags(e : ieee_fp_exceptions) -> fp_exception_flags =
  isla_bool_to_bit(ieee_has_inexact(e)) @
  isla_bool_to_bit(ieee_has_underflow(e)) @
  isla_bool_to_bit(ieee_has_overflow(e)) @
  isla_bool_to_bit(ieee_has_divide_by_zero(e)) @
  isla_bool_to_bit(ieee_has_invalid(e))

function ieee_empty_exceptions(invalid : bool) -> ieee_fp_exceptions =
  ieee_exception_facts(invalid, false, false, false, false)

function ieee_eq32_exceptions(a : bits(32), b : bits(32)) -> ieee_fp_exceptions = {
  let a_invalid = ieee_operand_invalid(false, a);
  let b_invalid = ieee_operand_invalid(false, b);
  ieee_empty_exceptions(strict_or_bool(a_invalid, b_invalid))
}

// Set signaling for ordered comparisons; quiet comparisons match Eq.
function ieee_lt32_exceptions(signaling : bool, a : bits(32), b : bits(32)) -> ieee_fp_exceptions = {
  let a_invalid = ieee_operand_invalid(signaling, a);
  let b_invalid = ieee_operand_invalid(signaling, b);
  ieee_empty_exceptions(strict_or_bool(a_invalid, b_invalid))
}

// Work in f64: every exact f32 Add/Sub is inside its normal exponent range.
// Directed bounds retain even a tiny term lost by a single wider rounding.
function ieee_f32_rounded_exceptions(rm : float_rounding_mode, lo : float64, hi : float64, result : float32) -> ieee_fp_exceptions = {
  let rw = fp32_to_fp64(round_nearest_ties_to_even(), result);
  let exact = strict_and_bool(fp64_eq(lo, rw), fp64_eq(hi, rw));
  let inexact = not_bool(exact);
  let abs_lo = fp64_abs(lo);
  let abs_hi = fp64_abs(hi);
  let lo_is_lower_magnitude = fp64_lteq(abs_lo, abs_hi);
  let lower = ite(lo_is_lower_magnitude, abs_lo, abs_hi);
  let upper = ite(lo_is_lower_magnitude, abs_hi, abs_lo);
  let maximum = fp64_from_ieee(0x47efffffe0000000);
  let overflow_midpoint = fp64_from_ieee(0x47effffff0000000);
  let overflow_power = fp64_from_ieee(0x47f0000000000000);
  let minimum_normal = fp64_from_ieee(0x3810000000000000);
  let tiny_predecessor = fp64_from_ieee(0x380fffffe0000000);
  let tiny_midpoint = fp64_from_ieee(0x380ffffff0000000);
  let nearest = strict_or_bool(rm == round_nearest_ties_to_even(), rm == round_nearest_ties_to_away());
  let negative = fp64_is_negative(lo);
  let outward = strict_or_bool(
    strict_and_bool(negative, rm == round_toward_negative()),
    strict_and_bool(not_bool(negative), rm == round_toward_positive())
  );
  let nearest_overflow = strict_and_bool(nearest, fp64_gteq(lower, overflow_midpoint));
  let outward_overflow = strict_and_bool(outward, fp64_gt(upper, maximum));
  let inward = strict_and_bool(not_bool(nearest), not_bool(outward));
  let inward_overflow = strict_and_bool(inward, fp64_gteq(lower, overflow_power));
  let overflow = strict_or_bool(nearest_overflow, strict_or_bool(outward_overflow, inward_overflow));
  let nearest_tiny = strict_and_bool(nearest, fp64_lt(lower, tiny_midpoint));
  let outward_tiny = strict_and_bool(outward, fp64_lteq(upper, tiny_predecessor));
  let inward_tiny = strict_and_bool(inward, fp64_lt(lower, minimum_normal));
  let tiny = strict_or_bool(nearest_tiny, strict_or_bool(outward_tiny, inward_tiny));
  let underflow = strict_and_bool(inexact, tiny);
  ieee_exception_facts(false, false, overflow, underflow, inexact)
}

function ieee_add32_exceptions(rm : float_rounding_mode, a : bits(32), b : bits(32), result : float32) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), ieee_operand_invalid(false, b));
  let invalid_inf = strict_and_bool(
    strict_and_bool(ieee_is_inf(a), ieee_is_inf(b)),
    not_bool(eq_anything(a[31], b[31]))
  );
  let finite = strict_and_bool(ieee_is_finite(a), ieee_is_finite(b));
  let invalid = strict_or_bool(invalid_nan, invalid_inf);
  if finite then {
    let x = fp32_to_fp64(round_nearest_ties_to_even(), fp32_from_ieee(a));
    let y = fp32_to_fp64(round_nearest_ties_to_even(), fp32_from_ieee(b));
    let lo = fp64_add(round_toward_negative(), x, y);
    let hi = fp64_add(round_toward_positive(), x, y);
    let rounded = ieee_f32_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}

function ieee_sub32_exceptions(rm : float_rounding_mode, a : bits(32), b : bits(32), result : float32) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), ieee_operand_invalid(false, b));
  let invalid_inf = strict_and_bool(
    strict_and_bool(ieee_is_inf(a), ieee_is_inf(b)),
    eq_anything(a[31], b[31])
  );
  let finite = strict_and_bool(ieee_is_finite(a), ieee_is_finite(b));
  let invalid = strict_or_bool(invalid_nan, invalid_inf);
  if finite then {
    let x = fp32_to_fp64(round_nearest_ties_to_even(), fp32_from_ieee(a));
    let y = fp32_to_fp64(round_nearest_ties_to_even(), fp32_from_ieee(b));
    let lo = fp64_sub(round_toward_negative(), x, y);
    let hi = fp64_sub(round_toward_positive(), x, y);
    let rounded = ieee_f32_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}
function ieee_eq16_exceptions(a : bits(16), b : bits(16)) -> ieee_fp_exceptions = {
  let a_invalid = ieee_operand_invalid(false, a);
  let b_invalid = ieee_operand_invalid(false, b);
  ieee_empty_exceptions(strict_or_bool(a_invalid, b_invalid))
}

function ieee_lt16_exceptions(signaling : bool, a : bits(16), b : bits(16)) -> ieee_fp_exceptions = {
  let a_invalid = ieee_operand_invalid(signaling, a);
  let b_invalid = ieee_operand_invalid(signaling, b);
  ieee_empty_exceptions(strict_or_bool(a_invalid, b_invalid))
}

function ieee_f16_rounded_exceptions(rm : float_rounding_mode, lo : float32, hi : float32, result : float16) -> ieee_fp_exceptions = {
  let rw = fp16_to_fp32(round_nearest_ties_to_even(), result);
  let exact = strict_and_bool(fp32_eq(lo, rw), fp32_eq(hi, rw));
  let inexact = not_bool(exact);
  let abs_lo = fp32_abs(lo);
  let abs_hi = fp32_abs(hi);
  let lo_is_lower_magnitude = fp32_lteq(abs_lo, abs_hi);
  let lower = ite(lo_is_lower_magnitude, abs_lo, abs_hi);
  let upper = ite(lo_is_lower_magnitude, abs_hi, abs_lo);
  let maximum = fp32_from_ieee(0x477fe000);
  let overflow_midpoint = fp32_from_ieee(0x477ff000);
  let overflow_power = fp32_from_ieee(0x47800000);
  let minimum_normal = fp32_from_ieee(0x38800000);
  let tiny_predecessor = fp32_from_ieee(0x387fe000);
  let tiny_midpoint = fp32_from_ieee(0x387ff000);
  let nearest = strict_or_bool(rm == round_nearest_ties_to_even(), rm == round_nearest_ties_to_away());
  let negative = fp32_is_negative(lo);
  let outward = strict_or_bool(
    strict_and_bool(negative, rm == round_toward_negative()),
    strict_and_bool(not_bool(negative), rm == round_toward_positive())
  );
  let nearest_overflow = strict_and_bool(nearest, fp32_gteq(lower, overflow_midpoint));
  let outward_overflow = strict_and_bool(outward, fp32_gt(upper, maximum));
  let inward = strict_and_bool(not_bool(nearest), not_bool(outward));
  let inward_overflow = strict_and_bool(inward, fp32_gteq(lower, overflow_power));
  let overflow = strict_or_bool(nearest_overflow, strict_or_bool(outward_overflow, inward_overflow));
  let nearest_tiny = strict_and_bool(nearest, fp32_lt(lower, tiny_midpoint));
  let outward_tiny = strict_and_bool(outward, fp32_lteq(upper, tiny_predecessor));
  let inward_tiny = strict_and_bool(inward, fp32_lt(lower, minimum_normal));
  let tiny = strict_or_bool(nearest_tiny, strict_or_bool(outward_tiny, inward_tiny));
  let underflow = strict_and_bool(inexact, tiny);
  ieee_exception_facts(false, false, overflow, underflow, inexact)
}

function ieee_add16_exceptions(rm : float_rounding_mode, a : bits(16), b : bits(16), result : float16) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), ieee_operand_invalid(false, b));
  let invalid_inf = strict_and_bool(
    strict_and_bool(ieee_is_inf(a), ieee_is_inf(b)),
    not_bool(eq_anything(a[15], b[15]))
  );
  let finite = strict_and_bool(ieee_is_finite(a), ieee_is_finite(b));
  let invalid = strict_or_bool(invalid_nan, invalid_inf);
  if finite then {
    let x = fp16_to_fp32(round_nearest_ties_to_even(), fp16_from_ieee(a));
    let y = fp16_to_fp32(round_nearest_ties_to_even(), fp16_from_ieee(b));
    let lo = fp32_add(round_toward_negative(), x, y);
    let hi = fp32_add(round_toward_positive(), x, y);
    let rounded = ieee_f16_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}

function ieee_sub16_exceptions(rm : float_rounding_mode, a : bits(16), b : bits(16), result : float16) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), ieee_operand_invalid(false, b));
  let invalid_inf = strict_and_bool(
    strict_and_bool(ieee_is_inf(a), ieee_is_inf(b)),
    eq_anything(a[15], b[15])
  );
  let finite = strict_and_bool(ieee_is_finite(a), ieee_is_finite(b));
  let invalid = strict_or_bool(invalid_nan, invalid_inf);
  if finite then {
    let x = fp16_to_fp32(round_nearest_ties_to_even(), fp16_from_ieee(a));
    let y = fp16_to_fp32(round_nearest_ties_to_even(), fp16_from_ieee(b));
    let lo = fp32_sub(round_toward_negative(), x, y);
    let hi = fp32_sub(round_toward_positive(), x, y);
    let rounded = ieee_f16_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}

function ieee_eq64_exceptions(a : bits(64), b : bits(64)) -> ieee_fp_exceptions = {
  let a_invalid = ieee_operand_invalid(false, a);
  let b_invalid = ieee_operand_invalid(false, b);
  ieee_empty_exceptions(strict_or_bool(a_invalid, b_invalid))
}

function ieee_lt64_exceptions(signaling : bool, a : bits(64), b : bits(64)) -> ieee_fp_exceptions = {
  let a_invalid = ieee_operand_invalid(signaling, a);
  let b_invalid = ieee_operand_invalid(signaling, b);
  ieee_empty_exceptions(strict_or_bool(a_invalid, b_invalid))
}

function ieee_f64_rounded_exceptions(rm : float_rounding_mode, lo : float128, hi : float128, result : float64) -> ieee_fp_exceptions = {
  let rw = fp64_to_fp128(round_nearest_ties_to_even(), result);
  let exact = strict_and_bool(fp128_eq(lo, rw), fp128_eq(hi, rw));
  let inexact = not_bool(exact);
  let abs_lo = fp128_abs(lo);
  let abs_hi = fp128_abs(hi);
  let lo_is_lower_magnitude = fp128_lteq(abs_lo, abs_hi);
  let lower = ite(lo_is_lower_magnitude, abs_lo, abs_hi);
  let upper = ite(lo_is_lower_magnitude, abs_hi, abs_lo);
  let maximum = fp128_from_ieee(0x43fefffffffffffff000000000000000);
  let overflow_midpoint = fp128_from_ieee(0x43fefffffffffffff800000000000000);
  let overflow_power = fp128_from_ieee(0x43ff0000000000000000000000000000);
  let minimum_normal = fp128_from_ieee(0x3c010000000000000000000000000000);
  let tiny_predecessor = fp128_from_ieee(0x3c00fffffffffffff000000000000000);
  let tiny_midpoint = fp128_from_ieee(0x3c00fffffffffffff800000000000000);
  let nearest = strict_or_bool(rm == round_nearest_ties_to_even(), rm == round_nearest_ties_to_away());
  let negative = fp128_is_negative(lo);
  let outward = strict_or_bool(
    strict_and_bool(negative, rm == round_toward_negative()),
    strict_and_bool(not_bool(negative), rm == round_toward_positive())
  );
  let nearest_overflow = strict_and_bool(nearest, fp128_gteq(lower, overflow_midpoint));
  let outward_overflow = strict_and_bool(outward, fp128_gt(upper, maximum));
  let inward = strict_and_bool(not_bool(nearest), not_bool(outward));
  let inward_overflow = strict_and_bool(inward, fp128_gteq(lower, overflow_power));
  let overflow = strict_or_bool(nearest_overflow, strict_or_bool(outward_overflow, inward_overflow));
  let nearest_tiny = strict_and_bool(nearest, fp128_lt(lower, tiny_midpoint));
  let outward_tiny = strict_and_bool(outward, fp128_lteq(upper, tiny_predecessor));
  let inward_tiny = strict_and_bool(inward, fp128_lt(lower, minimum_normal));
  let tiny = strict_or_bool(nearest_tiny, strict_or_bool(outward_tiny, inward_tiny));
  let underflow = strict_and_bool(inexact, tiny);
  ieee_exception_facts(false, false, overflow, underflow, inexact)
}

function ieee_add64_exceptions(rm : float_rounding_mode, a : bits(64), b : bits(64), result : float64) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), ieee_operand_invalid(false, b));
  let invalid_inf = strict_and_bool(
    strict_and_bool(ieee_is_inf(a), ieee_is_inf(b)),
    not_bool(eq_anything(a[63], b[63]))
  );
  let finite = strict_and_bool(ieee_is_finite(a), ieee_is_finite(b));
  let invalid = strict_or_bool(invalid_nan, invalid_inf);
  if finite then {
    let x = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(a));
    let y = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(b));
    let lo = fp128_add(round_toward_negative(), x, y);
    let hi = fp128_add(round_toward_positive(), x, y);
    let rounded = ieee_f64_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}

function ieee_sub64_exceptions(rm : float_rounding_mode, a : bits(64), b : bits(64), result : float64) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), ieee_operand_invalid(false, b));
  let invalid_inf = strict_and_bool(
    strict_and_bool(ieee_is_inf(a), ieee_is_inf(b)),
    eq_anything(a[63], b[63])
  );
  let finite = strict_and_bool(ieee_is_finite(a), ieee_is_finite(b));
  let invalid = strict_or_bool(invalid_nan, invalid_inf);
  if finite then {
    let x = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(a));
    let y = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(b));
    let lo = fp128_sub(round_toward_negative(), x, y);
    let hi = fp128_sub(round_toward_positive(), x, y);
    let rounded = ieee_f64_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}
function ieee_mul16_exceptions(rm : float_rounding_mode, a : bits(16), b : bits(16), result : float16) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), ieee_operand_invalid(false, b));
  let invalid_zero_inf = strict_or_bool(
    strict_and_bool(ieee_is_zero(a), ieee_is_inf(b)),
    strict_and_bool(ieee_is_inf(a), ieee_is_zero(b))
  );
  let valid = strict_and_bool(ieee_is_finite(a), ieee_is_finite(b));
  let invalid = strict_or_bool(invalid_nan, invalid_zero_inf);
  if valid then {
    let x = fp16_to_fp32(round_nearest_ties_to_even(), fp16_from_ieee(a));
    let y = fp16_to_fp32(round_nearest_ties_to_even(), fp16_from_ieee(b));
    let lo = fp32_mul(round_toward_negative(), x, y);
    let hi = fp32_mul(round_toward_positive(), x, y);
    let rounded = ieee_f16_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}

function ieee_div16_exceptions(rm : float_rounding_mode, a : bits(16), b : bits(16), result : float16) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), ieee_operand_invalid(false, b));
  let invalid_zero_zero = strict_and_bool(ieee_is_zero(a), ieee_is_zero(b));
  let invalid_inf_inf = strict_and_bool(ieee_is_inf(a), ieee_is_inf(b));
  let divide_by_zero = strict_and_bool(
    strict_and_bool(ieee_is_finite(a), not_bool(ieee_is_zero(a))),
    ieee_is_zero(b)
  );
  let valid = strict_and_bool(strict_and_bool(ieee_is_finite(a), ieee_is_finite(b)), not_bool(ieee_is_zero(b)));
  let invalid = strict_or_bool(invalid_nan, strict_or_bool(invalid_zero_zero, invalid_inf_inf));
  if valid then {
    let x = fp16_to_fp32(round_nearest_ties_to_even(), fp16_from_ieee(a));
    let y = fp16_to_fp32(round_nearest_ties_to_even(), fp16_from_ieee(b));
    let lo = fp32_div(round_toward_negative(), x, y);
    let hi = fp32_div(round_toward_positive(), x, y);
    let rounded = ieee_f16_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      divide_by_zero,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, divide_by_zero, false, false, false)
}

function ieee_sqrt16_exceptions(rm : float_rounding_mode, a : bits(16), result : float16) -> ieee_fp_exceptions = {
  let negative_nonzero = strict_and_bool(eq_anything(a[15], 0b1), not_bool(ieee_is_zero(a)));
  let invalid_negative = strict_and_bool(not_bool(ieee_is_nan(a)), negative_nonzero);
  let invalid_nan = ieee_operand_invalid(false, a);
  let valid = strict_or_bool(strict_and_bool(ieee_is_finite(a), not_bool(negative_nonzero)), ieee_is_zero(a));
  let invalid = strict_or_bool(invalid_nan, invalid_negative);
  if valid then {
    let x = fp16_to_fp32(round_nearest_ties_to_even(), fp16_from_ieee(a));
    let lo = fp32_sqrt(round_toward_negative(), x);
    let hi = fp32_sqrt(round_toward_positive(), x);
    let rounded = ieee_f16_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}

function ieee_fma16_exceptions(rm : float_rounding_mode, a : bits(16), b : bits(16), c : bits(16), result : float16) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), strict_or_bool(ieee_operand_invalid(false, b), ieee_operand_invalid(false, c)));
  let invalid_zero_inf = strict_or_bool(
    strict_and_bool(ieee_is_zero(a), ieee_is_inf(b)),
    strict_and_bool(ieee_is_inf(a), ieee_is_zero(b))
  );
  let valid_inf_product = strict_or_bool(
    strict_and_bool(ieee_is_inf(a), strict_and_bool(not_bool(ieee_is_nan(b)), not_bool(ieee_is_zero(b)))),
    strict_and_bool(ieee_is_inf(b), strict_and_bool(not_bool(ieee_is_nan(a)), not_bool(ieee_is_zero(a))))
  );
  let product_negative = not_bool(eq_anything(a[15], b[15]));
  let c_negative : bool = eq_anything(c[15], 0b1);
  let invalid_inf_cancel = strict_and_bool(
    strict_and_bool(valid_inf_product, ieee_is_inf(c)),
    strict_or_bool(
      strict_and_bool(product_negative, not_bool(c_negative)),
      strict_and_bool(not_bool(product_negative), c_negative)
    )
  );
  let valid = strict_and_bool(ieee_is_finite(a), strict_and_bool(ieee_is_finite(b), ieee_is_finite(c)));
  let invalid = strict_or_bool(invalid_nan, strict_or_bool(invalid_zero_inf, invalid_inf_cancel));
  if valid then {
    let x = fp16_to_fp32(round_nearest_ties_to_even(), fp16_from_ieee(a));
    let y = fp16_to_fp32(round_nearest_ties_to_even(), fp16_from_ieee(b));
    let z = fp16_to_fp32(round_nearest_ties_to_even(), fp16_from_ieee(c));
    let lo = fp32_fma(round_toward_negative(), x, y, z);
    let hi = fp32_fma(round_toward_positive(), x, y, z);
    let rounded = ieee_f16_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}

function ieee_mul32_exceptions(rm : float_rounding_mode, a : bits(32), b : bits(32), result : float32) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), ieee_operand_invalid(false, b));
  let invalid_zero_inf = strict_or_bool(
    strict_and_bool(ieee_is_zero(a), ieee_is_inf(b)),
    strict_and_bool(ieee_is_inf(a), ieee_is_zero(b))
  );
  let valid = strict_and_bool(ieee_is_finite(a), ieee_is_finite(b));
  let invalid = strict_or_bool(invalid_nan, invalid_zero_inf);
  if valid then {
    let x = fp32_to_fp64(round_nearest_ties_to_even(), fp32_from_ieee(a));
    let y = fp32_to_fp64(round_nearest_ties_to_even(), fp32_from_ieee(b));
    let lo = fp64_mul(round_toward_negative(), x, y);
    let hi = fp64_mul(round_toward_positive(), x, y);
    let rounded = ieee_f32_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}

function ieee_div32_exceptions(rm : float_rounding_mode, a : bits(32), b : bits(32), result : float32) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), ieee_operand_invalid(false, b));
  let invalid_zero_zero = strict_and_bool(ieee_is_zero(a), ieee_is_zero(b));
  let invalid_inf_inf = strict_and_bool(ieee_is_inf(a), ieee_is_inf(b));
  let divide_by_zero = strict_and_bool(
    strict_and_bool(ieee_is_finite(a), not_bool(ieee_is_zero(a))),
    ieee_is_zero(b)
  );
  let valid = strict_and_bool(strict_and_bool(ieee_is_finite(a), ieee_is_finite(b)), not_bool(ieee_is_zero(b)));
  let invalid = strict_or_bool(invalid_nan, strict_or_bool(invalid_zero_zero, invalid_inf_inf));
  if valid then {
    let x = fp32_to_fp64(round_nearest_ties_to_even(), fp32_from_ieee(a));
    let y = fp32_to_fp64(round_nearest_ties_to_even(), fp32_from_ieee(b));
    let lo = fp64_div(round_toward_negative(), x, y);
    let hi = fp64_div(round_toward_positive(), x, y);
    let rounded = ieee_f32_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      divide_by_zero,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, divide_by_zero, false, false, false)
}

function ieee_sqrt32_exceptions(rm : float_rounding_mode, a : bits(32), result : float32) -> ieee_fp_exceptions = {
  let negative_nonzero = strict_and_bool(eq_anything(a[31], 0b1), not_bool(ieee_is_zero(a)));
  let invalid_negative = strict_and_bool(not_bool(ieee_is_nan(a)), negative_nonzero);
  let invalid_nan = ieee_operand_invalid(false, a);
  let valid = strict_or_bool(strict_and_bool(ieee_is_finite(a), not_bool(negative_nonzero)), ieee_is_zero(a));
  let invalid = strict_or_bool(invalid_nan, invalid_negative);
  if valid then {
    let x = fp32_to_fp64(round_nearest_ties_to_even(), fp32_from_ieee(a));
    let lo = fp64_sqrt(round_toward_negative(), x);
    let hi = fp64_sqrt(round_toward_positive(), x);
    let rounded = ieee_f32_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}

function ieee_fma32_exceptions(rm : float_rounding_mode, a : bits(32), b : bits(32), c : bits(32), result : float32) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), strict_or_bool(ieee_operand_invalid(false, b), ieee_operand_invalid(false, c)));
  let invalid_zero_inf = strict_or_bool(
    strict_and_bool(ieee_is_zero(a), ieee_is_inf(b)),
    strict_and_bool(ieee_is_inf(a), ieee_is_zero(b))
  );
  let valid_inf_product = strict_or_bool(
    strict_and_bool(ieee_is_inf(a), strict_and_bool(not_bool(ieee_is_nan(b)), not_bool(ieee_is_zero(b)))),
    strict_and_bool(ieee_is_inf(b), strict_and_bool(not_bool(ieee_is_nan(a)), not_bool(ieee_is_zero(a))))
  );
  let product_negative = not_bool(eq_anything(a[31], b[31]));
  let c_negative : bool = eq_anything(c[31], 0b1);
  let invalid_inf_cancel = strict_and_bool(
    strict_and_bool(valid_inf_product, ieee_is_inf(c)),
    strict_or_bool(
      strict_and_bool(product_negative, not_bool(c_negative)),
      strict_and_bool(not_bool(product_negative), c_negative)
    )
  );
  let valid = strict_and_bool(ieee_is_finite(a), strict_and_bool(ieee_is_finite(b), ieee_is_finite(c)));
  let invalid = strict_or_bool(invalid_nan, strict_or_bool(invalid_zero_inf, invalid_inf_cancel));
  if valid then {
    let x = fp32_to_fp64(round_nearest_ties_to_even(), fp32_from_ieee(a));
    let y = fp32_to_fp64(round_nearest_ties_to_even(), fp32_from_ieee(b));
    let z = fp32_to_fp64(round_nearest_ties_to_even(), fp32_from_ieee(c));
    let lo = fp64_fma(round_toward_negative(), x, y, z);
    let hi = fp64_fma(round_toward_positive(), x, y, z);
    let rounded = ieee_f32_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}

function ieee_mul64_exceptions(rm : float_rounding_mode, a : bits(64), b : bits(64), result : float64) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), ieee_operand_invalid(false, b));
  let invalid_zero_inf = strict_or_bool(
    strict_and_bool(ieee_is_zero(a), ieee_is_inf(b)),
    strict_and_bool(ieee_is_inf(a), ieee_is_zero(b))
  );
  let valid = strict_and_bool(ieee_is_finite(a), ieee_is_finite(b));
  let invalid = strict_or_bool(invalid_nan, invalid_zero_inf);
  if valid then {
    let x = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(a));
    let y = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(b));
    let lo = fp128_mul(round_toward_negative(), x, y);
    let hi = fp128_mul(round_toward_positive(), x, y);
    let rounded = ieee_f64_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}

function ieee_div64_exceptions(rm : float_rounding_mode, a : bits(64), b : bits(64), result : float64) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), ieee_operand_invalid(false, b));
  let invalid_zero_zero = strict_and_bool(ieee_is_zero(a), ieee_is_zero(b));
  let invalid_inf_inf = strict_and_bool(ieee_is_inf(a), ieee_is_inf(b));
  let divide_by_zero = strict_and_bool(
    strict_and_bool(ieee_is_finite(a), not_bool(ieee_is_zero(a))),
    ieee_is_zero(b)
  );
  let valid = strict_and_bool(strict_and_bool(ieee_is_finite(a), ieee_is_finite(b)), not_bool(ieee_is_zero(b)));
  let invalid = strict_or_bool(invalid_nan, strict_or_bool(invalid_zero_zero, invalid_inf_inf));
  if valid then {
    let x = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(a));
    let y = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(b));
    let lo = fp128_div(round_toward_negative(), x, y);
    let hi = fp128_div(round_toward_positive(), x, y);
    let rounded = ieee_f64_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      divide_by_zero,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, divide_by_zero, false, false, false)
}

function ieee_sqrt64_exceptions(rm : float_rounding_mode, a : bits(64), result : float64) -> ieee_fp_exceptions = {
  let negative_nonzero = strict_and_bool(eq_anything(a[63], 0b1), not_bool(ieee_is_zero(a)));
  let invalid_negative = strict_and_bool(not_bool(ieee_is_nan(a)), negative_nonzero);
  let invalid_nan = ieee_operand_invalid(false, a);
  let valid = strict_or_bool(strict_and_bool(ieee_is_finite(a), not_bool(negative_nonzero)), ieee_is_zero(a));
  let invalid = strict_or_bool(invalid_nan, invalid_negative);
  if valid then {
    let x = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(a));
    let lo = fp128_sqrt(round_toward_negative(), x);
    let hi = fp128_sqrt(round_toward_positive(), x);
    let rounded = ieee_f64_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}

function ieee_fma64_exceptions(rm : float_rounding_mode, a : bits(64), b : bits(64), c : bits(64), result : float64) -> ieee_fp_exceptions = {
  let invalid_nan = strict_or_bool(ieee_operand_invalid(false, a), strict_or_bool(ieee_operand_invalid(false, b), ieee_operand_invalid(false, c)));
  let invalid_zero_inf = strict_or_bool(
    strict_and_bool(ieee_is_zero(a), ieee_is_inf(b)),
    strict_and_bool(ieee_is_inf(a), ieee_is_zero(b))
  );
  let valid_inf_product = strict_or_bool(
    strict_and_bool(ieee_is_inf(a), strict_and_bool(not_bool(ieee_is_nan(b)), not_bool(ieee_is_zero(b)))),
    strict_and_bool(ieee_is_inf(b), strict_and_bool(not_bool(ieee_is_nan(a)), not_bool(ieee_is_zero(a))))
  );
  let product_negative = not_bool(eq_anything(a[63], b[63]));
  let c_negative : bool = eq_anything(c[63], 0b1);
  let invalid_inf_cancel = strict_and_bool(
    strict_and_bool(valid_inf_product, ieee_is_inf(c)),
    strict_or_bool(
      strict_and_bool(product_negative, not_bool(c_negative)),
      strict_and_bool(not_bool(product_negative), c_negative)
    )
  );
  let valid = strict_and_bool(ieee_is_finite(a), strict_and_bool(ieee_is_finite(b), ieee_is_finite(c)));
  let invalid = strict_or_bool(invalid_nan, strict_or_bool(invalid_zero_inf, invalid_inf_cancel));
  if valid then {
    let x = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(a));
    let y = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(b));
    let z = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(c));
    let lo = fp128_fma(round_toward_negative(), x, y, z);
    let hi = fp128_fma(round_toward_positive(), x, y, z);
    let rounded = ieee_f64_rounded_exceptions(rm, lo, hi, result);
    ieee_exception_facts(
      invalid,
      false,
      ieee_has_overflow(rounded),
      ieee_has_underflow(rounded),
      ieee_has_inexact(rounded)
    )
  } else
    ieee_exception_facts(invalid, false, false, false, false)
}
// Conversion sources are exactly representable in f128. Unlike arithmetic,
// no directed interval is needed for their exact value.
function ieee_exact_threshold_exceptions(
  rm : float_rounding_mode, x : float128, result : float128,
  maximum : float128, overflow_midpoint : float128, overflow_power : float128,
  minimum_normal : float128, tiny_predecessor : float128, tiny_midpoint : float128
) -> ieee_fp_exceptions = {
  let inexact = not_bool(fp128_eq(x, result));
  let magnitude = fp128_abs(x);
  let nearest = strict_or_bool(rm == round_nearest_ties_to_even(), rm == round_nearest_ties_to_away());
  let negative = fp128_is_negative(x);
  let outward = strict_or_bool(
    strict_and_bool(negative, rm == round_toward_negative()),
    strict_and_bool(not_bool(negative), rm == round_toward_positive())
  );
  let inward = strict_and_bool(not_bool(nearest), not_bool(outward));
  let overflow = strict_or_bool(
    strict_and_bool(nearest, fp128_gteq(magnitude, overflow_midpoint)),
    strict_or_bool(
      strict_and_bool(outward, fp128_gt(magnitude, maximum)),
      strict_and_bool(inward, fp128_gteq(magnitude, overflow_power))
    )
  );
  let tiny = strict_or_bool(
    strict_and_bool(nearest, fp128_lt(magnitude, tiny_midpoint)),
    strict_or_bool(
      strict_and_bool(outward, fp128_lteq(magnitude, tiny_predecessor)),
      strict_and_bool(inward, fp128_lt(magnitude, minimum_normal))
    )
  );
  let underflow = strict_and_bool(inexact, tiny);
  ieee_exception_facts(false, false, overflow, underflow, inexact)
}

function ieee_f32_bits_as_f128(raw : bits(32)) -> float128 =
  fp32_to_fp128(round_nearest_ties_to_even(), fp32_from_ieee(raw))

function ieee_f64_bits_as_f128(raw : bits(64)) -> float128 =
  fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(raw))

function ieee_exact16_exceptions(rm : float_rounding_mode, x : float128, result : float128) -> ieee_fp_exceptions =
  ieee_exact_threshold_exceptions(rm, x, result,
    ieee_f32_bits_as_f128(0x477fe000), ieee_f32_bits_as_f128(0x477ff000), ieee_f32_bits_as_f128(0x47800000),
    ieee_f32_bits_as_f128(0x38800000), ieee_f32_bits_as_f128(0x387fe000), ieee_f32_bits_as_f128(0x387ff000))

function ieee_exact32_exceptions(rm : float_rounding_mode, x : float128, result : float128) -> ieee_fp_exceptions =
  ieee_exact_threshold_exceptions(rm, x, result,
    ieee_f64_bits_as_f128(0x47efffffe0000000), ieee_f64_bits_as_f128(0x47effffff0000000), ieee_f64_bits_as_f128(0x47f0000000000000),
    ieee_f64_bits_as_f128(0x3810000000000000), ieee_f64_bits_as_f128(0x380fffffe0000000), ieee_f64_bits_as_f128(0x380ffffff0000000))

function ieee_exact64_exceptions(rm : float_rounding_mode, x : float128, result : float128) -> ieee_fp_exceptions =
  ieee_exact_threshold_exceptions(rm, x, result,
    fp128_from_ieee(0x43fefffffffffffff000000000000000),
    fp128_from_ieee(0x43fefffffffffffff800000000000000),
    fp128_from_ieee(0x43ff0000000000000000000000000000),
    fp128_from_ieee(0x3c010000000000000000000000000000),
    fp128_from_ieee(0x3c00fffffffffffff000000000000000),
    fp128_from_ieee(0x3c00fffffffffffff800000000000000))

function ieee_exact_bf16_exceptions(rm : float_rounding_mode, x : float128, result : float128) -> ieee_fp_exceptions =
  ieee_exact_threshold_exceptions(rm, x, result,
    ieee_f64_bits_as_f128(0x47efe00000000000), ieee_f64_bits_as_f128(0x47eff00000000000), ieee_f64_bits_as_f128(0x47f0000000000000),
    ieee_f64_bits_as_f128(0x3810000000000000), ieee_f64_bits_as_f128(0x380fe00000000000), ieee_f64_bits_as_f128(0x380ff00000000000))

function ieee_fp_to_int_core(x : float128, rounded : float128, finite : bool, is_unsigned : bool, width64 : bool) -> ieee_fp_exceptions = {
  if finite then {
    let lower_signed = ite(width64,
      fp128_from_ieee(0xc03e0000000000000000000000000000),
      fp128_from_ieee(0xc01e0000000000000000000000000000));
    let upper_signed = ite(width64,
      fp128_from_ieee(0x403e0000000000000000000000000000),
      fp128_from_ieee(0x401e0000000000000000000000000000));
    let upper_unsigned = ite(width64,
      fp128_from_ieee(0x403f0000000000000000000000000000),
      fp128_from_ieee(0x401f0000000000000000000000000000));
    let lower = ite(is_unsigned, fp128_zero(), lower_signed);
    let upper = ite(is_unsigned, upper_unsigned, upper_signed);
    let valid = strict_and_bool(fp128_gteq(rounded, lower), fp128_lt(rounded, upper));
    if valid then {
      let inexact = not_bool(fp128_eq(x, rounded));
      ieee_exception_facts(false, false, false, false, inexact)
    } else
      ieee_empty_exceptions(true)
  } else
    ieee_empty_exceptions(true)
}

function ieee_round16_exceptions(a : bits(16), result : float16, raise_inexact : bool) -> ieee_fp_exceptions = {
  let invalid_nan = ieee_operand_invalid(false, a);
  let finite = ieee_is_finite(a);
  if finite then {
    let x = fp16_from_ieee(a);
    let inexact = strict_and_bool(raise_inexact, not_bool(fp16_eq(x, result)));
    ieee_exception_facts(invalid_nan, false, false, false, inexact)
  } else
    ieee_empty_exceptions(invalid_nan)
}

function ieee_fp16_to_int_exceptions(a : bits(16), rounded : float16, is_unsigned : bool, width64 : bool) -> ieee_fp_exceptions = {
  let x = fp16_to_fp128(round_nearest_ties_to_even(), fp16_from_ieee(a));
  let y = fp16_to_fp128(round_nearest_ties_to_even(), rounded);
  ieee_fp_to_int_core(x, y, ieee_is_finite(a), is_unsigned, width64)
}

function ieee_int32_to_fp16_exceptions(rm : float_rounding_mode, a : bits(32), is_unsigned : bool, result : float16) -> ieee_fp_exceptions = {
  let signed_value = fp128_from_signed(round_nearest_ties_to_even(), a);
  let unsigned_value = fp128_from_unsigned(round_nearest_ties_to_even(), a);
  let exact = ite(is_unsigned, unsigned_value, signed_value);
  let rounded = fp16_to_fp128(round_nearest_ties_to_even(), result);
  let flags = ieee_exact16_exceptions(rm, exact, rounded);
  ieee_exception_facts(
    false,
    false,
    ieee_has_overflow(flags),
    false,
    ieee_has_inexact(flags)
  )
}

function ieee_int64_to_fp16_exceptions(rm : float_rounding_mode, a : bits(64), is_unsigned : bool, result : float16) -> ieee_fp_exceptions = {
  let signed_value = fp128_from_signed(round_nearest_ties_to_even(), a);
  let unsigned_value = fp128_from_unsigned(round_nearest_ties_to_even(), a);
  let exact = ite(is_unsigned, unsigned_value, signed_value);
  let rounded = fp16_to_fp128(round_nearest_ties_to_even(), result);
  let flags = ieee_exact16_exceptions(rm, exact, rounded);
  ieee_exception_facts(
    false,
    false,
    ieee_has_overflow(flags),
    false,
    ieee_has_inexact(flags)
  )
}

function ieee_round32_exceptions(a : bits(32), result : float32, raise_inexact : bool) -> ieee_fp_exceptions = {
  let invalid_nan = ieee_operand_invalid(false, a);
  let finite = ieee_is_finite(a);
  if finite then {
    let x = fp32_from_ieee(a);
    let inexact = strict_and_bool(raise_inexact, not_bool(fp32_eq(x, result)));
    ieee_exception_facts(invalid_nan, false, false, false, inexact)
  } else
    ieee_empty_exceptions(invalid_nan)
}

function ieee_fp32_to_int_exceptions(a : bits(32), rounded : float32, is_unsigned : bool, width64 : bool) -> ieee_fp_exceptions = {
  let x = fp32_to_fp128(round_nearest_ties_to_even(), fp32_from_ieee(a));
  let y = fp32_to_fp128(round_nearest_ties_to_even(), rounded);
  ieee_fp_to_int_core(x, y, ieee_is_finite(a), is_unsigned, width64)
}

function ieee_int32_to_fp32_exceptions(rm : float_rounding_mode, a : bits(32), is_unsigned : bool, result : float32) -> ieee_fp_exceptions = {
  let signed_value = fp128_from_signed(round_nearest_ties_to_even(), a);
  let unsigned_value = fp128_from_unsigned(round_nearest_ties_to_even(), a);
  let exact = ite(is_unsigned, unsigned_value, signed_value);
  let rounded = fp32_to_fp128(round_nearest_ties_to_even(), result);
  let flags = ieee_exact32_exceptions(rm, exact, rounded);
  ieee_exception_facts(
    false,
    false,
    ieee_has_overflow(flags),
    false,
    ieee_has_inexact(flags)
  )
}

function ieee_int64_to_fp32_exceptions(rm : float_rounding_mode, a : bits(64), is_unsigned : bool, result : float32) -> ieee_fp_exceptions = {
  let signed_value = fp128_from_signed(round_nearest_ties_to_even(), a);
  let unsigned_value = fp128_from_unsigned(round_nearest_ties_to_even(), a);
  let exact = ite(is_unsigned, unsigned_value, signed_value);
  let rounded = fp32_to_fp128(round_nearest_ties_to_even(), result);
  let flags = ieee_exact32_exceptions(rm, exact, rounded);
  ieee_exception_facts(
    false,
    false,
    ieee_has_overflow(flags),
    false,
    ieee_has_inexact(flags)
  )
}

function ieee_round64_exceptions(a : bits(64), result : float64, raise_inexact : bool) -> ieee_fp_exceptions = {
  let invalid_nan = ieee_operand_invalid(false, a);
  let finite = ieee_is_finite(a);
  if finite then {
    let x = fp64_from_ieee(a);
    let inexact = strict_and_bool(raise_inexact, not_bool(fp64_eq(x, result)));
    ieee_exception_facts(invalid_nan, false, false, false, inexact)
  } else
    ieee_empty_exceptions(invalid_nan)
}

function ieee_fp64_to_int_exceptions(a : bits(64), rounded : float64, is_unsigned : bool, width64 : bool) -> ieee_fp_exceptions = {
  let x = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(a));
  let y = fp64_to_fp128(round_nearest_ties_to_even(), rounded);
  ieee_fp_to_int_core(x, y, ieee_is_finite(a), is_unsigned, width64)
}

function ieee_int32_to_fp64_exceptions(rm : float_rounding_mode, a : bits(32), is_unsigned : bool, result : float64) -> ieee_fp_exceptions = {
  let signed_value = fp128_from_signed(round_nearest_ties_to_even(), a);
  let unsigned_value = fp128_from_unsigned(round_nearest_ties_to_even(), a);
  let exact = ite(is_unsigned, unsigned_value, signed_value);
  let rounded = fp64_to_fp128(round_nearest_ties_to_even(), result);
  let flags = ieee_exact64_exceptions(rm, exact, rounded);
  ieee_exception_facts(
    false,
    false,
    ieee_has_overflow(flags),
    false,
    ieee_has_inexact(flags)
  )
}

function ieee_int64_to_fp64_exceptions(rm : float_rounding_mode, a : bits(64), is_unsigned : bool, result : float64) -> ieee_fp_exceptions = {
  let signed_value = fp128_from_signed(round_nearest_ties_to_even(), a);
  let unsigned_value = fp128_from_unsigned(round_nearest_ties_to_even(), a);
  let exact = ite(is_unsigned, unsigned_value, signed_value);
  let rounded = fp64_to_fp128(round_nearest_ties_to_even(), result);
  let flags = ieee_exact64_exceptions(rm, exact, rounded);
  ieee_exception_facts(
    false,
    false,
    ieee_has_overflow(flags),
    false,
    ieee_has_inexact(flags)
  )
}

function ieee_convert32_to_16_exceptions(rm : float_rounding_mode, a : bits(32), result : float16) -> ieee_fp_exceptions = {
  let invalid_nan = ieee_operand_invalid(false, a);
  let finite = ieee_is_finite(a);
  if finite then {
    let exact = fp32_to_fp128(round_nearest_ties_to_even(), fp32_from_ieee(a));
    let rounded = fp16_to_fp128(round_nearest_ties_to_even(), result);
    let facts = ieee_exact16_exceptions(rm, exact, rounded);
    facts
  } else
    ieee_empty_exceptions(invalid_nan)
}

function ieee_convert64_to_16_exceptions(rm : float_rounding_mode, a : bits(64), result : float16) -> ieee_fp_exceptions = {
  let invalid_nan = ieee_operand_invalid(false, a);
  let finite = ieee_is_finite(a);
  if finite then {
    let exact = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(a));
    let rounded = fp16_to_fp128(round_nearest_ties_to_even(), result);
    let facts = ieee_exact16_exceptions(rm, exact, rounded);
    facts
  } else
    ieee_empty_exceptions(invalid_nan)
}

function ieee_convert64_to_32_exceptions(rm : float_rounding_mode, a : bits(64), result : float32) -> ieee_fp_exceptions = {
  let invalid_nan = ieee_operand_invalid(false, a);
  let finite = ieee_is_finite(a);
  if finite then {
    let exact = fp64_to_fp128(round_nearest_ties_to_even(), fp64_from_ieee(a));
    let rounded = fp32_to_fp128(round_nearest_ties_to_even(), result);
    let facts = ieee_exact32_exceptions(rm, exact, rounded);
    facts
  } else
    ieee_empty_exceptions(invalid_nan)
}

function ieee_widen16_to_32_exceptions(a : bits(16)) -> ieee_fp_exceptions =
  ieee_empty_exceptions(ieee_operand_invalid(false, a))

function ieee_widen16_to_64_exceptions(a : bits(16)) -> ieee_fp_exceptions =
  ieee_empty_exceptions(ieee_operand_invalid(false, a))

function ieee_widen32_to_64_exceptions(a : bits(32)) -> ieee_fp_exceptions =
  ieee_empty_exceptions(ieee_operand_invalid(false, a))

function ieee_bf16_from_f32_exceptions(rm : float_rounding_mode, a : bits(32), result_bits : bits(16)) -> ieee_fp_exceptions = {
  let invalid_nan = ieee_operand_invalid(false, a);
  let finite = ieee_is_finite(a);
  if finite then {
    let exact = ieee_f32_bits_as_f128(a);
    let rounded = ieee_f32_bits_as_f128(result_bits @ 0x0000);
    let facts = ieee_exact_bf16_exceptions(rm, exact, rounded);
    facts
  } else
    ieee_empty_exceptions(invalid_nan)
}

function ieee_rod32_to_16(a : bits(32)) -> (ieee_fp_exceptions, bits(16)) = {
  let invalid_nan = ieee_operand_invalid(false, a);
  let finite = ieee_is_finite(a);
  let x = fp32_from_ieee(a);
  let base = fp32_to_fp16(round_toward_zero(), x);
  let base_bits = fp16_to_ieee(base);
  let flags = if finite then {
    let exact = ieee_f32_bits_as_f128(a);
    let rounded = fp16_to_fp128(round_nearest_ties_to_even(), base);
    let facts = ieee_exact16_exceptions(round_toward_zero(), exact, rounded);
    facts
  } else ieee_empty_exceptions(invalid_nan);
  (flags, ite(ieee_has_inexact(flags), base_bits | 0x0001, base_bits))
}

function ieee_rod64_to_32(a : bits(64)) -> (ieee_fp_exceptions, bits(32)) = {
  let invalid_nan = ieee_operand_invalid(false, a);
  let finite = ieee_is_finite(a);
  let x = fp64_from_ieee(a);
  let base = fp64_to_fp32(round_toward_zero(), x);
  let base_bits = fp32_to_ieee(base);
  let flags = if finite then {
    let exact = ieee_f64_bits_as_f128(a);
    let rounded = fp32_to_fp128(round_nearest_ties_to_even(), base);
    let facts = ieee_exact32_exceptions(round_toward_zero(), exact, rounded);
    facts
  } else ieee_empty_exceptions(invalid_nan);
  (flags, ite(ieee_has_inexact(flags), base_bits | 0x00000001, base_bits))
}

