// =======================================================================================
// This Sail RISC-V architecture model is subject to the BSD two-clause license.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================
// SYMBOLIC implementations whose floating-point format is f64.


function riscv_f64_result_bits(result : float64) -> bits_D =
  (if fp64_is_nan(result) then riscv_canonical_nan64() else fp64_to_ieee(result))

function riscv_f64Eq(a : bits_D, b : bits_D) -> (bits_fflags, bool) = {
  let result = fp64_eq(fp64_from_ieee(a), fp64_from_ieee(b));
  (riscv_pack_ieee_flags(ieee_eq64_exceptions(a, b)), result)
}

function riscv_f64Lt(a : bits_D, b : bits_D) -> (bits_fflags, bool) = {
  let result = fp64_lt(fp64_from_ieee(a), fp64_from_ieee(b));
  (riscv_pack_ieee_flags(ieee_lt64_exceptions(true, a, b)), result)
}

function riscv_f64Lt_quiet(a : bits_D, b : bits_D) -> (bits_fflags, bool) = {
  let result = fp64_lt(fp64_from_ieee(a), fp64_from_ieee(b));
  (riscv_pack_ieee_flags(ieee_lt64_exceptions(false, a, b)), result)
}

function riscv_f64Le(a : bits_D, b : bits_D) -> (bits_fflags, bool) = {
  let result = fp64_lteq(fp64_from_ieee(a), fp64_from_ieee(b));
  (riscv_pack_ieee_flags(ieee_lt64_exceptions(true, a, b)), result)
}

function riscv_f64Le_quiet(a : bits_D, b : bits_D) -> (bits_fflags, bool) = {
  let result = fp64_lteq(fp64_from_ieee(a), fp64_from_ieee(b));
  (riscv_pack_ieee_flags(ieee_lt64_exceptions(false, a, b)), result)
}

function riscv_f64Add(rm : bits_rm, a : bits_D, b : bits_D) -> (bits_fflags, bits_D) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let result = fp64_add(mode, fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_add64_exceptions(mode, a, b, result);
  (riscv_pack_ieee_flags(flags), riscv_f64_result_bits(result))
}

function riscv_f64Sub(rm : bits_rm, a : bits_D, b : bits_D) -> (bits_fflags, bits_D) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let result = fp64_sub(mode, fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_sub64_exceptions(mode, a, b, result);
  (riscv_pack_ieee_flags(flags), riscv_f64_result_bits(result))
}

function riscv_f64Mul(rm : bits_rm, a : bits_D, b : bits_D) -> (bits_fflags, bits_D) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let result = fp64_mul(mode, fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_mul64_exceptions(mode, a, b, result);
  (riscv_pack_ieee_flags(flags), riscv_f64_result_bits(result))
}

function riscv_f64Div(rm : bits_rm, a : bits_D, b : bits_D) -> (bits_fflags, bits_D) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let result = fp64_div(mode, fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_div64_exceptions(mode, a, b, result);
  (riscv_pack_ieee_flags(flags), riscv_f64_result_bits(result))
}

function riscv_f64Sqrt(rm : bits_rm, a : bits_D) -> (bits_fflags, bits_D) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let result = fp64_sqrt(mode, fp64_from_ieee(a));
  let flags = ieee_sqrt64_exceptions(mode, a, result);
  (riscv_pack_ieee_flags(flags), riscv_f64_result_bits(result))
}

function riscv_f64MulAdd(rm : bits_rm, a : bits_D, b : bits_D, c : bits_D) -> (bits_fflags, bits_D) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let result = fp64_fma(mode, fp64_from_ieee(a), fp64_from_ieee(b), fp64_from_ieee(c));
  let flags = ieee_fma64_exceptions(mode, a, b, c, result);
  (riscv_pack_ieee_flags(flags), riscv_f64_result_bits(result))
}

function riscv_f64roundToInt(rm : bits_rm, a : bits_D, raise_inexact : bool) -> (bits_fflags, bits_D) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let result = fp64_round_to_integral(mode, fp64_from_ieee(a));
  let flags = ieee_round64_exceptions(a, result, raise_inexact);
  (riscv_pack_ieee_flags(flags), riscv_f64_result_bits(result))
}

function riscv_f64ToI32(rm : bits_rm, a : bits_D) -> (bits_fflags, bits_W) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let rounded = fp64_round_to_integral(mode, fp64_from_ieee(a));
  let flags = ieee_fp64_to_int_exceptions(a, rounded, false, false);
  let candidate = fp64_to_signed32(round_toward_zero(), rounded);
  let positive = strict_or_bool(ieee_is_nan(a), eq_anything(a[63], 0b0));
  let invalid = ite(positive, 0x7fffffff, 0x80000000);
  (riscv_pack_ieee_flags(flags), ite(ieee_has_invalid(flags), invalid, candidate))
}

function riscv_f64ToUi32(rm : bits_rm, a : bits_D) -> (bits_fflags, bits_WU) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let rounded = fp64_round_to_integral(mode, fp64_from_ieee(a));
  let flags = ieee_fp64_to_int_exceptions(a, rounded, true, false);
  let candidate = fp64_to_unsigned32(round_toward_zero(), rounded);
  let positive = strict_or_bool(ieee_is_nan(a), eq_anything(a[63], 0b0));
  let invalid = ite(positive, 0xffffffff, 0x00000000);
  (riscv_pack_ieee_flags(flags), ite(ieee_has_invalid(flags), invalid, candidate))
}

function riscv_f64ToI64(rm : bits_rm, a : bits_D) -> (bits_fflags, bits_L) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let rounded = fp64_round_to_integral(mode, fp64_from_ieee(a));
  let flags = ieee_fp64_to_int_exceptions(a, rounded, false, true);
  let candidate = fp64_to_signed64(round_toward_zero(), rounded);
  let positive = strict_or_bool(ieee_is_nan(a), eq_anything(a[63], 0b0));
  let invalid = ite(positive, 0x7fffffffffffffff, 0x8000000000000000);
  (riscv_pack_ieee_flags(flags), ite(ieee_has_invalid(flags), invalid, candidate))
}

function riscv_f64ToUi64(rm : bits_rm, a : bits_D) -> (bits_fflags, bits_LU) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let rounded = fp64_round_to_integral(mode, fp64_from_ieee(a));
  let flags = ieee_fp64_to_int_exceptions(a, rounded, true, true);
  let candidate = fp64_to_unsigned64(round_toward_zero(), rounded);
  let positive = strict_or_bool(ieee_is_nan(a), eq_anything(a[63], 0b0));
  let invalid = ite(positive, 0xffffffffffffffff, 0x0000000000000000);
  (riscv_pack_ieee_flags(flags), ite(ieee_has_invalid(flags), invalid, candidate))
}

function riscv_i32ToF64(rm : bits_rm, a : bits_W) -> (bits_fflags, bits_D) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let result = fp64_from_signed(mode, a);
  let flags = ieee_int32_to_fp64_exceptions(mode, a, false, result);
  (riscv_pack_ieee_flags(flags), fp64_to_ieee(result))
}

function riscv_ui32ToF64(rm : bits_rm, a : bits_WU) -> (bits_fflags, bits_D) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let result = fp64_from_unsigned(mode, a);
  let flags = ieee_int32_to_fp64_exceptions(mode, a, true, result);
  (riscv_pack_ieee_flags(flags), fp64_to_ieee(result))
}

function riscv_i64ToF64(rm : bits_rm, a : bits_L) -> (bits_fflags, bits_D) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let result = fp64_from_signed(mode, a);
  let flags = ieee_int64_to_fp64_exceptions(mode, a, false, result);
  (riscv_pack_ieee_flags(flags), fp64_to_ieee(result))
}

function riscv_ui64ToF64(rm : bits_rm, a : bits_LU) -> (bits_fflags, bits_D) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let result = fp64_from_unsigned(mode, a);
  let flags = ieee_int64_to_fp64_exceptions(mode, a, true, result);
  (riscv_pack_ieee_flags(flags), fp64_to_ieee(result))
}

function riscv_f64ToF16(rm : bits_rm, a : bits_D) -> (bits_fflags, bits_H) = {
  let mode = riscv_valid_rm_to_ieee(rm);
  let result = fp64_to_fp16(mode, fp64_from_ieee(a));
  let flags = ieee_convert64_to_16_exceptions(mode, a, result);
  let bits = (if fp16_is_nan(result) then riscv_canonical_nan16() else fp16_to_ieee(result));
  (riscv_pack_ieee_flags(flags), bits)
}

function riscv_f64ToF32(rm : bits_rm, a : bits_D) -> (bits_fflags, bits_S) = {
  if rm == 0b110 then {
    let (exceptions, rod_bits) = ieee_rod64_to_32(a);
    let bits = if ieee_is_nan(a) then riscv_canonical_nan32() else rod_bits;
    (riscv_pack_ieee_flags(exceptions), bits)
  } else {
    let mode = riscv_valid_rm_to_ieee(rm);
    let result = fp64_to_fp32(mode, fp64_from_ieee(a));
    let exceptions = ieee_convert64_to_32_exceptions(mode, a, result);
    let bits = if ieee_is_nan(a) then riscv_canonical_nan32() else fp32_to_ieee(result);
    (riscv_pack_ieee_flags(exceptions), bits)
  }
}

