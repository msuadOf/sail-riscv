// =======================================================================================
// This Sail RISC-V architecture model is subject to the BSD two-clause license.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================
// SYMBOLIC implementations whose floating-point format is f32.


function riscv_f32_symbolic_bits(value : float32) -> bits_S =
  if fp32_is_nan(value) then riscv_canonical_nan32() else fp32_to_ieee(value)

// The ROD candidate probe uses RTZ instead of passing RM=6 to native FP.
// The conversion wrapper selects ROD before decoding an ordinary RM.
function riscv_f32_to_f16_normal_rm_bits(rm_bits : bits_rm) -> bits_rm =
  ite(rm_bits == 0b110, 0b001, rm_bits)

function riscv_f32Eq(a : bits_S, b : bits_S) -> (bits_fflags, bool) = {
  let left = fp32_from_ieee(a);
  let right = fp32_from_ieee(b);
  let result = fp32_eq(left, right);
  let exceptions = ieee_eq32_exceptions(a, b);
  (riscv_pack_ieee_flags(exceptions), result)
}

function riscv_f32Lt(a : bits_S, b : bits_S) -> (bits_fflags, bool) = {
  let result = fp32_lt(fp32_from_ieee(a), fp32_from_ieee(b));
  let exceptions = ieee_lt32_exceptions(true, a, b);
  (riscv_pack_ieee_flags(exceptions), result)
}

function riscv_f32Lt_quiet(a : bits_S, b : bits_S) -> (bits_fflags, bool) = {
  let result = fp32_lt(fp32_from_ieee(a), fp32_from_ieee(b));
  let exceptions = ieee_lt32_exceptions(false, a, b);
  (riscv_pack_ieee_flags(exceptions), result)
}

function riscv_f32Le(a : bits_S, b : bits_S) -> (bits_fflags, bool) = {
  let result = fp32_lteq(fp32_from_ieee(a), fp32_from_ieee(b));
  let exceptions = ieee_lt32_exceptions(true, a, b);
  (riscv_pack_ieee_flags(exceptions), result)
}

function riscv_f32Le_quiet(a : bits_S, b : bits_S) -> (bits_fflags, bool) = {
  let result = fp32_lteq(fp32_from_ieee(a), fp32_from_ieee(b));
  let exceptions = ieee_lt32_exceptions(false, a, b);
  (riscv_pack_ieee_flags(exceptions), result)
}

function riscv_f32Add(rm_bits : bits_rm, a : bits_S, b : bits_S) -> (bits_fflags, bits_S) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp32_add(rm, fp32_from_ieee(a), fp32_from_ieee(b));
  let exceptions = ieee_add32_exceptions(rm, a, b, result);
  (riscv_pack_ieee_flags(exceptions), riscv_f32_symbolic_bits(result))
}

function riscv_f32Sub(rm_bits : bits_rm, a : bits_S, b : bits_S) -> (bits_fflags, bits_S) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp32_sub(rm, fp32_from_ieee(a), fp32_from_ieee(b));
  let exceptions = ieee_sub32_exceptions(rm, a, b, result);
  (riscv_pack_ieee_flags(exceptions), riscv_f32_symbolic_bits(result))
}

function riscv_f32Mul(rm_bits : bits_rm, a : bits_S, b : bits_S) -> (bits_fflags, bits_S) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp32_mul(rm, fp32_from_ieee(a), fp32_from_ieee(b));
  let exceptions = ieee_mul32_exceptions(rm, a, b, result);
  (riscv_pack_ieee_flags(exceptions), riscv_f32_symbolic_bits(result))
}

function riscv_f32Div(rm_bits : bits_rm, a : bits_S, b : bits_S) -> (bits_fflags, bits_S) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp32_div(rm, fp32_from_ieee(a), fp32_from_ieee(b));
  let exceptions = ieee_div32_exceptions(rm, a, b, result);
  (riscv_pack_ieee_flags(exceptions), riscv_f32_symbolic_bits(result))
}

function riscv_f32Sqrt(rm_bits : bits_rm, a : bits_S) -> (bits_fflags, bits_S) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp32_sqrt(rm, fp32_from_ieee(a));
  let exceptions = ieee_sqrt32_exceptions(rm, a, result);
  (riscv_pack_ieee_flags(exceptions), riscv_f32_symbolic_bits(result))
}

function riscv_f32MulAdd(rm_bits : bits_rm, a : bits_S, b : bits_S, c : bits_S) -> (bits_fflags, bits_S) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp32_fma(rm, fp32_from_ieee(a), fp32_from_ieee(b), fp32_from_ieee(c));
  let exceptions = ieee_fma32_exceptions(rm, a, b, c, result);
  (riscv_pack_ieee_flags(exceptions), riscv_f32_symbolic_bits(result))
}

function riscv_f32roundToInt(rm_bits : bits_rm, a : bits_S, raise_inexact : bool) -> (bits_fflags, bits_S) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp32_round_to_integral(rm, fp32_from_ieee(a));
  let exceptions = ieee_round32_exceptions(a, result, raise_inexact);
  (riscv_pack_ieee_flags(exceptions), riscv_f32_symbolic_bits(result))
}

function riscv_f32ToI32(rm_bits : bits_rm, a : bits_S) -> (bits_fflags, bits_W) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let rounded = fp32_round_to_integral(rm, fp32_from_ieee(a));
  let exceptions = ieee_fp32_to_int_exceptions(a, rounded, false, false);
  let candidate = fp32_to_signed32(round_toward_zero(), rounded);
  let invalid_result = ite(ieee_is_nan(a), 0x7fffffff,
    ite(eq_anything(a[31], 0b1), 0x80000000, 0x7fffffff));
  (riscv_pack_ieee_flags(exceptions), ite(ieee_has_invalid(exceptions), invalid_result, candidate))
}

function riscv_f32ToUi32(rm_bits : bits_rm, a : bits_S) -> (bits_fflags, bits_WU) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let rounded = fp32_round_to_integral(rm, fp32_from_ieee(a));
  let exceptions = ieee_fp32_to_int_exceptions(a, rounded, true, false);
  let candidate = fp32_to_unsigned32(round_toward_zero(), rounded);
  let invalid_result = ite(ieee_is_nan(a), 0xffffffff,
    ite(eq_anything(a[31], 0b1), 0x00000000, 0xffffffff));
  (riscv_pack_ieee_flags(exceptions), ite(ieee_has_invalid(exceptions), invalid_result, candidate))
}

function riscv_f32ToI64(rm_bits : bits_rm, a : bits_S) -> (bits_fflags, bits_L) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let rounded = fp32_round_to_integral(rm, fp32_from_ieee(a));
  let exceptions = ieee_fp32_to_int_exceptions(a, rounded, false, true);
  let candidate = fp32_to_signed64(round_toward_zero(), rounded);
  let invalid_result = ite(ieee_is_nan(a), 0x7fffffffffffffff,
    ite(eq_anything(a[31], 0b1), 0x8000000000000000, 0x7fffffffffffffff));
  (riscv_pack_ieee_flags(exceptions), ite(ieee_has_invalid(exceptions), invalid_result, candidate))
}

function riscv_f32ToUi64(rm_bits : bits_rm, a : bits_S) -> (bits_fflags, bits_LU) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let rounded = fp32_round_to_integral(rm, fp32_from_ieee(a));
  let exceptions = ieee_fp32_to_int_exceptions(a, rounded, true, true);
  let candidate = fp32_to_unsigned64(round_toward_zero(), rounded);
  let invalid_result = ite(ieee_is_nan(a), 0xffffffffffffffff,
    ite(eq_anything(a[31], 0b1), 0x0000000000000000, 0xffffffffffffffff));
  (riscv_pack_ieee_flags(exceptions), ite(ieee_has_invalid(exceptions), invalid_result, candidate))
}

function riscv_i32ToF32(rm_bits : bits_rm, a : bits_W) -> (bits_fflags, bits_S) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp32_from_signed(rm, a);
  let exceptions = ieee_int32_to_fp32_exceptions(rm, a, false, result);
  (riscv_pack_ieee_flags(exceptions), riscv_f32_symbolic_bits(result))
}

function riscv_ui32ToF32(rm_bits : bits_rm, a : bits_WU) -> (bits_fflags, bits_S) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp32_from_unsigned(rm, a);
  let exceptions = ieee_int32_to_fp32_exceptions(rm, a, true, result);
  (riscv_pack_ieee_flags(exceptions), riscv_f32_symbolic_bits(result))
}

function riscv_i64ToF32(rm_bits : bits_rm, a : bits_L) -> (bits_fflags, bits_S) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp32_from_signed(rm, a);
  let exceptions = ieee_int64_to_fp32_exceptions(rm, a, false, result);
  (riscv_pack_ieee_flags(exceptions), riscv_f32_symbolic_bits(result))
}

function riscv_ui64ToF32(rm_bits : bits_rm, a : bits_LU) -> (bits_fflags, bits_S) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp32_from_unsigned(rm, a);
  let exceptions = ieee_int64_to_fp32_exceptions(rm, a, true, result);
  (riscv_pack_ieee_flags(exceptions), riscv_f32_symbolic_bits(result))
}

function riscv_f32ToF64(rm_bits : bits_rm, a : bits_S) -> (bits_fflags, bits_D) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp32_to_fp64(rm, fp32_from_ieee(a));
  let exceptions = ieee_widen32_to_64_exceptions(a);
  let bits = (if fp64_is_nan(result) then riscv_canonical_nan64() else fp64_to_ieee(result));
  (riscv_pack_ieee_flags(exceptions), bits)
}

function riscv_f32ToF16(rm_bits : bits_rm, a : bits_S) -> (bits_fflags, bits_H) = {
  if rm_bits == 0b110 then {
    let (exceptions, rod_bits) = ieee_rod32_to_16(a);
    let bits = if ieee_is_nan(a) then riscv_canonical_nan16() else rod_bits;
    (riscv_pack_ieee_flags(exceptions), bits)
  } else {
    let rm = riscv_valid_rm_to_ieee(rm_bits);
    let result = fp32_to_fp16(rm, fp32_from_ieee(a));
    let exceptions = ieee_convert32_to_16_exceptions(rm, a, result);
    let bits = if fp16_is_nan(result) then riscv_canonical_nan16() else fp16_to_ieee(result);
    (riscv_pack_ieee_flags(exceptions), bits)
  }
}

function riscv_f32ToBF16(rm_bits : bits_rm, a : bits_S) -> (bits_fflags, bits_BF16) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let raw = fp32_to_bf16(rm, fp32_from_ieee(a));
  let exceptions = ieee_bf16_from_f32_exceptions(rm, a, raw);
  (riscv_pack_ieee_flags(exceptions), (if ieee_is_nan(a) then riscv_canonical_nan_bf16() else raw))
}

