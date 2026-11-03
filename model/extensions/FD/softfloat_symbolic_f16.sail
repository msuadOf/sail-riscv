// =======================================================================================
// This Sail RISC-V architecture model is subject to the BSD two-clause license.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================
// SYMBOLIC implementations whose floating-point format is f16.


function riscv_f16Add(rm_bits : bits_rm, a : bits_H, b : bits_H) -> (bits_fflags, bits_H) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp16_add(rm, fp16_from_ieee(a), fp16_from_ieee(b));
  let exceptions = ieee_add16_exceptions(rm, a, b, result);
  (riscv_pack_ieee_flags(exceptions), (if fp16_is_nan(result) then riscv_canonical_nan16() else fp16_to_ieee(result)))
}

function riscv_f16Sub(rm_bits : bits_rm, a : bits_H, b : bits_H) -> (bits_fflags, bits_H) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp16_sub(rm, fp16_from_ieee(a), fp16_from_ieee(b));
  let exceptions = ieee_sub16_exceptions(rm, a, b, result);
  (riscv_pack_ieee_flags(exceptions), (if fp16_is_nan(result) then riscv_canonical_nan16() else fp16_to_ieee(result)))
}

function riscv_f16Mul(rm_bits : bits_rm, a : bits_H, b : bits_H) -> (bits_fflags, bits_H) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp16_mul(rm, fp16_from_ieee(a), fp16_from_ieee(b));
  let exceptions = ieee_mul16_exceptions(rm, a, b, result);
  (riscv_pack_ieee_flags(exceptions), (if fp16_is_nan(result) then riscv_canonical_nan16() else fp16_to_ieee(result)))
}

function riscv_f16Div(rm_bits : bits_rm, a : bits_H, b : bits_H) -> (bits_fflags, bits_H) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp16_div(rm, fp16_from_ieee(a), fp16_from_ieee(b));
  let exceptions = ieee_div16_exceptions(rm, a, b, result);
  (riscv_pack_ieee_flags(exceptions), (if fp16_is_nan(result) then riscv_canonical_nan16() else fp16_to_ieee(result)))
}

function riscv_f16MulAdd(rm_bits : bits_rm, a : bits_H, b : bits_H, c : bits_H) -> (bits_fflags, bits_H) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp16_fma(rm, fp16_from_ieee(a), fp16_from_ieee(b), fp16_from_ieee(c));
  let exceptions = ieee_fma16_exceptions(rm, a, b, c, result);
  (riscv_pack_ieee_flags(exceptions), (if fp16_is_nan(result) then riscv_canonical_nan16() else fp16_to_ieee(result)))
}

function riscv_f16Sqrt(rm_bits : bits_rm, a : bits_H) -> (bits_fflags, bits_H) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp16_sqrt(rm, fp16_from_ieee(a));
  let exceptions = ieee_sqrt16_exceptions(rm, a, result);
  (riscv_pack_ieee_flags(exceptions), (if fp16_is_nan(result) then riscv_canonical_nan16() else fp16_to_ieee(result)))
}

function riscv_f16ToI32(rm_bits : bits_rm, a : bits_H) -> (bits_fflags, bits_W) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let rounded = fp16_round_to_integral(rm, fp16_from_ieee(a));
  let exceptions = ieee_fp16_to_int_exceptions(a, rounded, false, false);
  let candidate = fp16_to_signed32(round_toward_zero(), rounded);
  let invalid = ite(ieee_is_nan(a), 0x7fffffff,
    ite(eq_anything(a[15], 0b1), 0x80000000, 0x7fffffff));
  (riscv_pack_ieee_flags(exceptions), ite(ieee_has_invalid(exceptions), invalid, candidate))
}

function riscv_f16ToUi32(rm_bits : bits_rm, a : bits_H) -> (bits_fflags, bits_WU) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let rounded = fp16_round_to_integral(rm, fp16_from_ieee(a));
  let exceptions = ieee_fp16_to_int_exceptions(a, rounded, true, false);
  let candidate = fp16_to_unsigned32(round_toward_zero(), rounded);
  let invalid = ite(ieee_is_nan(a), 0xffffffff,
    ite(eq_anything(a[15], 0b1), 0x00000000, 0xffffffff));
  (riscv_pack_ieee_flags(exceptions), ite(ieee_has_invalid(exceptions), invalid, candidate))
}

function riscv_f16ToI64(rm_bits : bits_rm, a : bits_H) -> (bits_fflags, bits_L) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let rounded = fp16_round_to_integral(rm, fp16_from_ieee(a));
  let exceptions = ieee_fp16_to_int_exceptions(a, rounded, false, true);
  let candidate = fp16_to_signed64(round_toward_zero(), rounded);
  let invalid = ite(ieee_is_nan(a), 0x7fffffffffffffff,
    ite(eq_anything(a[15], 0b1), 0x8000000000000000, 0x7fffffffffffffff));
  (riscv_pack_ieee_flags(exceptions), ite(ieee_has_invalid(exceptions), invalid, candidate))
}

function riscv_f16ToUi64(rm_bits : bits_rm, a : bits_H) -> (bits_fflags, bits_LU) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let rounded = fp16_round_to_integral(rm, fp16_from_ieee(a));
  let exceptions = ieee_fp16_to_int_exceptions(a, rounded, true, true);
  let candidate = fp16_to_unsigned64(round_toward_zero(), rounded);
  let invalid = ite(ieee_is_nan(a), 0xffffffffffffffff,
    ite(eq_anything(a[15], 0b1), 0x0000000000000000, 0xffffffffffffffff));
  (riscv_pack_ieee_flags(exceptions), ite(ieee_has_invalid(exceptions), invalid, candidate))
}

function riscv_i32ToF16(rm_bits : bits_rm, a : bits_W) -> (bits_fflags, bits_H) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp16_from_signed(rm, a);
  let exceptions = ieee_int32_to_fp16_exceptions(rm, a, false, result);
  (riscv_pack_ieee_flags(exceptions), fp16_to_ieee(result))
}

function riscv_ui32ToF16(rm_bits : bits_rm, a : bits_WU) -> (bits_fflags, bits_H) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp16_from_unsigned(rm, a);
  let exceptions = ieee_int32_to_fp16_exceptions(rm, a, true, result);
  (riscv_pack_ieee_flags(exceptions), fp16_to_ieee(result))
}

function riscv_i64ToF16(rm_bits : bits_rm, a : bits_L) -> (bits_fflags, bits_H) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp16_from_signed(rm, a);
  let exceptions = ieee_int64_to_fp16_exceptions(rm, a, false, result);
  (riscv_pack_ieee_flags(exceptions), fp16_to_ieee(result))
}

function riscv_ui64ToF16(rm_bits : bits_rm, a : bits_LU) -> (bits_fflags, bits_H) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp16_from_unsigned(rm, a);
  let exceptions = ieee_int64_to_fp16_exceptions(rm, a, true, result);
  (riscv_pack_ieee_flags(exceptions), fp16_to_ieee(result))
}

function riscv_f16roundToInt(rm_bits : bits_rm, a : bits_H, raise_inexact : bool) -> (bits_fflags, bits_H) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp16_round_to_integral(rm, fp16_from_ieee(a));
  let exceptions = ieee_round16_exceptions(a, result, raise_inexact);
  (riscv_pack_ieee_flags(exceptions), (if fp16_is_nan(result) then riscv_canonical_nan16() else fp16_to_ieee(result)))
}

function riscv_f16ToF32(rm_bits : bits_rm, a : bits_H) -> (bits_fflags, bits_S) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp16_to_fp32(rm, fp16_from_ieee(a));
  let exceptions = ieee_widen16_to_32_exceptions(a);
  (riscv_pack_ieee_flags(exceptions), (if ieee_is_nan(a) then riscv_canonical_nan32() else fp32_to_ieee(result)))
}

function riscv_f16ToF64(rm_bits : bits_rm, a : bits_H) -> (bits_fflags, bits_D) = {
  let rm = riscv_valid_rm_to_ieee(rm_bits);
  let result = fp16_to_fp64(rm, fp16_from_ieee(a));
  let exceptions = ieee_widen16_to_64_exceptions(a);
  (riscv_pack_ieee_flags(exceptions), (if ieee_is_nan(a) then riscv_canonical_nan64() else fp64_to_ieee(result)))
}

function riscv_f16Lt(a : bits_H, b : bits_H) -> (bits_fflags, bool) = {
  let result = fp16_lt(fp16_from_ieee(a), fp16_from_ieee(b));
  let exceptions = ieee_lt16_exceptions(true, a, b);
  (riscv_pack_ieee_flags(exceptions), result)
}

function riscv_f16Lt_quiet(a : bits_H, b : bits_H) -> (bits_fflags, bool) = {
  let result = fp16_lt(fp16_from_ieee(a), fp16_from_ieee(b));
  let exceptions = ieee_lt16_exceptions(false, a, b);
  (riscv_pack_ieee_flags(exceptions), result)
}

function riscv_f16Le(a : bits_H, b : bits_H) -> (bits_fflags, bool) = {
  let result = fp16_lteq(fp16_from_ieee(a), fp16_from_ieee(b));
  let exceptions = ieee_lt16_exceptions(true, a, b);
  (riscv_pack_ieee_flags(exceptions), result)
}

function riscv_f16Le_quiet(a : bits_H, b : bits_H) -> (bits_fflags, bool) = {
  let result = fp16_lteq(fp16_from_ieee(a), fp16_from_ieee(b));
  let exceptions = ieee_lt16_exceptions(false, a, b);
  (riscv_pack_ieee_flags(exceptions), result)
}

function riscv_f16Eq(a : bits_H, b : bits_H) -> (bits_fflags, bool) = {
  let result = fp16_eq(fp16_from_ieee(a), fp16_from_ieee(b));
  let exceptions = ieee_eq16_exceptions(a, b);
  (riscv_pack_ieee_flags(exceptions), result)
}

