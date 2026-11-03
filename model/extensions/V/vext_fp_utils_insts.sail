// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// ******************************************************************************
// This file implements functions used by vector instructions.
// ******************************************************************************

// Check for valid floating-point operation types
// 1. Valid element width of floating-point numbers
// 2. Valid floating-point rounding mode
function valid_fp_op(SEW : sew_bitsize, rm_3b : bits(3)) -> bool = {
  // SEW=8 is valid for conversions between INT8 and FP16(vfncvt[.rtz].x[u].f.w, etc.)
  if SEW < 8 then false
  else if SEW > 64 then false
  else if eq_anything(rm_3b, 0b101) then false
  else if eq_anything(rm_3b, 0b110) then false
  else if eq_anything(rm_3b, 0b111) then false
  else true
}

// Ordinary vector FP instructions have no SEW=8 encoding. Widening and
// narrowing conversions use valid_fp_op directly because some accept INT8.
function valid_fp_standard_op(SEW : sew_bitsize, rm_3b : bits(3)) -> bool =
  strict_and_bool(SEW != 8, valid_fp_op(SEW, rm_3b))

// a. Normal check for floating-point instructions
function illegal_fp_normal(vd : vregidx, vm : bits(1), SEW : sew_bitsize, rm_3b : bits(3)) -> bool = {
  if not_bool(valid_vtype()) then true
  else if not_bool(valid_rd_mask(vd, vm)) then true
  else if not_bool(valid_fp_standard_op(SEW, rm_3b)) then true
  else false
}

// b. Masked check for floating-point instructions encoded with vm = 0
function illegal_fp_vd_masked(vd : vregidx, SEW : sew_bitsize, rm_3b : bits(3)) -> bool = {
  not(valid_vtype()) | vd == zvreg | not(valid_fp_standard_op(SEW, rm_3b))
}

// c. Unmasked check for floating-point instructions encoded with vm = 1
function illegal_fp_vd_unmasked(SEW : sew_bitsize, rm_3b : bits(3)) -> bool = {
  not(valid_vtype()) | not(valid_fp_standard_op(SEW, rm_3b))
}

// d. Variable width check for floating-point widening/narrowing instructions
function illegal_fp_variable_width(vd : vregidx, vm : bits(1), SEW : sew_bitsize, rm_3b : bits(3), SEW_new : int, LMUL_pow_new : int) -> bool = {
  not(valid_vtype()) | not(valid_rd_mask(vd, vm)) | not(valid_fp_op(SEW, rm_3b)) |
  not(valid_eew_emul(SEW_new, LMUL_pow_new))
}

// Widening arithmetic starts at SEW=16. Conversion instructions retain the
// general width check because some INT8 conversions are valid.
function illegal_fp_standard_variable_width(vd : vregidx, vm : bits(1), SEW : sew_bitsize, rm_3b : bits(3), SEW_new : int, LMUL_pow_new : int) -> bool =
  strict_or_bool(SEW == 8, illegal_fp_variable_width(vd, vm, SEW, rm_3b, SEW_new, LMUL_pow_new))

// e. Normal check for floating-point reduction instructions
function illegal_fp_reduction(SEW : sew_bitsize, rm_3b : bits(3)) -> bool = {
  // Reductions have no SEW=8 encoding, but still check RM independently.
  if not_bool(valid_vtype()) then true
  else if not_bool(eq_anything(vstart, zeros())) then true
  else if not_bool(valid_fp_standard_op(SEW, rm_3b)) then true
  else false
}

// f. Variable width check for floating-point widening reduction instructions
function illegal_fp_widening_reduction(SEW : sew_bitsize, rm_3b : bits(3), EEW : int) -> bool = {
  illegal_fp_reduction(SEW, rm_3b) | not(EEW >= 8 & EEW <= elen)
}

// Floating point classification functions
val f_is_neg_inf : forall 'm, 'm in {16, 32, 64}. bits('m) -> bool
function f_is_neg_inf(xf) = {
  match 'm {
    16 => f_is_neg_inf_H(xf),
    32 => f_is_neg_inf_S(xf),
    64 => f_is_neg_inf_D(xf)
  }
}

val f_is_neg_norm : forall 'm, 'm in {16, 32, 64}. bits('m) -> bool
function f_is_neg_norm(xf) = {
  match 'm {
    16 => f_is_neg_norm_H(xf),
    32 => f_is_neg_norm_S(xf),
    64 => f_is_neg_norm_D(xf)
  }
}

val f_is_neg_subnorm : forall 'm, 'm in {16, 32, 64}. bits('m) -> bool
function f_is_neg_subnorm(xf) = {
  match 'm {
    16 => f_is_neg_subnorm_H(xf),
    32 => f_is_neg_subnorm_S(xf),
    64 => f_is_neg_subnorm_D(xf)
  }
}

val f_is_neg_zero : forall 'm, 'm in {16, 32, 64}. bits('m) -> bool
function f_is_neg_zero(xf) = {
  match 'm {
    16 => f_is_neg_zero_H(xf),
    32 => f_is_neg_zero_S(xf),
    64 => f_is_neg_zero_D(xf)
  }
}

val f_is_pos_zero : forall 'm, 'm in {16, 32, 64}. bits('m) -> bool
function f_is_pos_zero(xf) = {
  match 'm {
    16 => f_is_pos_zero_H(xf),
    32 => f_is_pos_zero_S(xf),
    64 => f_is_pos_zero_D(xf)
  }
}

val f_is_pos_subnorm : forall 'm, 'm in {16, 32, 64}. bits('m) -> bool
function f_is_pos_subnorm(xf) = {
  match 'm {
    16 => f_is_pos_subnorm_H(xf),
    32 => f_is_pos_subnorm_S(xf),
    64 => f_is_pos_subnorm_D(xf)
  }
}

val f_is_pos_norm : forall 'm, 'm in {16, 32, 64}. bits('m) -> bool
function f_is_pos_norm(xf) = {
  match 'm {
    16 => f_is_pos_norm_H(xf),
    32 => f_is_pos_norm_S(xf),
    64 => f_is_pos_norm_D(xf)
  }
}

val f_is_pos_inf : forall 'm, 'm in {16, 32, 64}. bits('m) -> bool
function f_is_pos_inf(xf) = {
  match 'm {
    16 => f_is_pos_inf_H(xf),
    32 => f_is_pos_inf_S(xf),
    64 => f_is_pos_inf_D(xf)
  }
}

val f_is_SNaN : forall 'm, 'm in {16, 32, 64}. bits('m) -> bool
function f_is_SNaN(xf) = {
  match 'm {
    16 => f_is_SNaN_H(xf),
    32 => f_is_SNaN_S(xf),
    64 => f_is_SNaN_D(xf)
  }
}

val f_is_QNaN : forall 'm, 'm in {16, 32, 64}. bits('m) -> bool
function f_is_QNaN(xf) = {
  match 'm {
    16 => f_is_QNaN_H(xf),
    32 => f_is_QNaN_S(xf),
    64 => f_is_QNaN_D(xf)
  }
}

val f_is_NaN : forall 'm, 'm in {16, 32, 64}. bits('m) -> bool
function f_is_NaN(xf) = {
  match 'm {
    16 => f_is_NaN_H(xf),
    32 => f_is_NaN_S(xf),
    64 => f_is_NaN_D(xf)
  }
}

// Scalar register shaping for floating point operations
val get_scalar_fp : forall 'n, 'n in {16, 32, 64}. (fregidx, int('n)) -> bits('n)
function get_scalar_fp(rs1, SEW) = {
  assert(flen >= SEW, "invalid vector floating-point type width: FLEN < SEW");
  match SEW {
    16 => F_H(rs1),
    32 => F_S(rs1),
    64 => F_D(rs1)
  }
}

// Get the floating point rounding mode from csr fcsr
function get_fp_rounding_mode() -> rounding_mode = encdec_rounding_mode(fcsr[FRM])

// Negate a floating point number
val negate_fp : forall 'm, 'm in {16, 32, 64}. bits('m) -> bits('m)
function negate_fp(xf) = {
  match 'm {
    16 => negate_H(xf),
    32 => negate_S(xf),
    64 => negate_D(xf)
  }
}

// Floating point functions using softfloat interface
// SYMBOLIC lanes compute flags and bits without changing fcsr. The original
// helpers below retain their per-call side effects for the C++ model.
$ifdef SYMBOLIC
val fp_add_pure : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m)) -> (bits_fflags, bits('m))
function fp_add_pure(rm_3b, op1, op2) = match 'm {
  16 => riscv_f16Add(rm_3b, op1, op2),
  32 => riscv_f32Add(rm_3b, op1, op2),
  64 => riscv_f64Add(rm_3b, op1, op2)
}

val fp_sub_pure : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m)) -> (bits_fflags, bits('m))
function fp_sub_pure(rm_3b, op1, op2) = match 'm {
  16 => riscv_f16Sub(rm_3b, op1, op2),
  32 => riscv_f32Sub(rm_3b, op1, op2),
  64 => riscv_f64Sub(rm_3b, op1, op2)
}

val fp_mul_pure : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m)) -> (bits_fflags, bits('m))
function fp_mul_pure(rm_3b, op1, op2) = match 'm {
  16 => riscv_f16Mul(rm_3b, op1, op2),
  32 => riscv_f32Mul(rm_3b, op1, op2),
  64 => riscv_f64Mul(rm_3b, op1, op2)
}

val fp_div_pure : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m)) -> (bits_fflags, bits('m))
function fp_div_pure(rm_3b, op1, op2) = match 'm {
  16 => riscv_f16Div(rm_3b, op1, op2),
  32 => riscv_f32Div(rm_3b, op1, op2),
  64 => riscv_f64Div(rm_3b, op1, op2)
}

val fp_muladd_pure : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m), bits('m)) -> (bits_fflags, bits('m))
function fp_muladd_pure(rm_3b, op1, op2, opadd) = match 'm {
  16 => riscv_f16MulAdd(rm_3b, op1, op2, opadd),
  32 => riscv_f32MulAdd(rm_3b, op1, op2, opadd),
  64 => riscv_f64MulAdd(rm_3b, op1, op2, opadd)
}

val fp_nmuladd_pure : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m), bits('m)) -> (bits_fflags, bits('m))
function fp_nmuladd_pure(rm_3b, op1, op2, opadd) =
  fp_muladd_pure(rm_3b, negate_fp(op1), op2, opadd)

val fp_mulsub_pure : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m), bits('m)) -> (bits_fflags, bits('m))
function fp_mulsub_pure(rm_3b, op1, op2, opsub) =
  fp_muladd_pure(rm_3b, op1, op2, negate_fp(opsub))

val fp_nmulsub_pure : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m), bits('m)) -> (bits_fflags, bits('m))
function fp_nmulsub_pure(rm_3b, op1, op2, opsub) =
  fp_muladd_pure(rm_3b, negate_fp(op1), op2, negate_fp(opsub))

val fp_eq_pure : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> (bits_fflags, bool)
function fp_eq_pure(op1, op2) = match 'm {
  16 => riscv_f16Eq(op1, op2),
  32 => riscv_f32Eq(op1, op2),
  64 => riscv_f64Eq(op1, op2)
}

val fp_ne_pure : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> (bits_fflags, bool)
function fp_ne_pure(op1, op2) = {
  let (fflags, eq) = fp_eq_pure(op1, op2);
  (fflags, not_bool(eq))
}

val fp_lt_pure : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> (bits_fflags, bool)
function fp_lt_pure(op1, op2) = match 'm {
  16 => riscv_f16Lt(op1, op2),
  32 => riscv_f32Lt(op1, op2),
  64 => riscv_f64Lt(op1, op2)
}

val fp_le_pure : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> (bits_fflags, bool)
function fp_le_pure(op1, op2) = match 'm {
  16 => riscv_f16Le(op1, op2),
  32 => riscv_f32Le(op1, op2),
  64 => riscv_f64Le(op1, op2)
}

val fp_gt_pure : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> (bits_fflags, bool)
function fp_gt_pure(op1, op2) = {
  let (fflags, le) = fp_le_pure(op1, op2);
  (fflags, ite(eq_anything(fflags[4], 0b1), false, not_bool(le)))
}

val fp_ge_pure : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> (bits_fflags, bool)
function fp_ge_pure(op1, op2) = {
  let (fflags, lt) = fp_lt_pure(op1, op2);
  (fflags, ite(eq_anything(fflags[4], 0b1), false, not_bool(lt)))
}

val fp_widen_pure : forall 'm, 'm in {16, 32}. (bits(3), bits('m)) -> (bits_fflags, bits('m * 2))
function fp_widen_pure(rm_3b, nval) = match 'm {
  16 => riscv_f16ToF32(rm_3b, nval),
  32 => riscv_f32ToF64(rm_3b, nval)
}

val fp_class_onehot_pure : forall 'm, 'm in {16, 32, 64}. bits('m) -> bits(10)
function fp_class_onehot_pure(raw) = {
  let fp : float_bits('m) = float_decompose(raw);
  let negative = eq_anything(fp.sign, 0b1);
  let positive = not_bool(negative);
  let exp_zero = eq_anything(fp.exp, zeros());
  let exp_ones = eq_anything(fp.exp, ones());
  let mant_zero = eq_anything(fp.mantissa, zeros());
  let nan = strict_and_bool(exp_ones, not_bool(mant_zero));
  let quiet_zero : bool = match 'm {
    16 => eq_anything(raw[9], 0b0),
    32 => eq_anything(raw[22], 0b0),
    64 => eq_anything(raw[51], 0b0)
  };
  let snan = strict_and_bool(nan, quiet_zero);
  let qnan = strict_and_bool(nan, not_bool(snan));
  let inf = strict_and_bool(exp_ones, mant_zero);
  let zero = strict_and_bool(exp_zero, mant_zero);
  let sub = strict_and_bool(exp_zero, not_bool(mant_zero));
  let normal = strict_and_bool(not_bool(exp_zero), not_bool(exp_ones));
  if qnan then 0b1000000000
  else if snan then 0b0100000000
  else if positive then {
    if inf then 0b0010000000
    else if normal then 0b0001000000
    else if sub then 0b0000100000
    else 0b0000010000
  } else {
    if zero then 0b0000001000
    else if sub then 0b0000000100
    else if normal then 0b0000000010
    else 0b0000000001
  }
}
$endif

val fp_add: forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m)) -> bits('m)
function fp_add(rm_3b, op1, op2) = {
  let (fflags, result_val) : (bits_fflags, bits('m)) = match 'm {
    16  => riscv_f16Add(rm_3b, op1, op2),
    32  => riscv_f32Add(rm_3b, op1, op2),
    64  => riscv_f64Add(rm_3b, op1, op2)
  };
  accrue_fflags(fflags);
  result_val
}

val fp_sub: forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m)) -> bits('m)
function fp_sub(rm_3b, op1, op2) = {
  let (fflags, result_val) : (bits_fflags, bits('m)) = match 'm {
    16  => riscv_f16Sub(rm_3b, op1, op2),
    32  => riscv_f32Sub(rm_3b, op1, op2),
    64  => riscv_f64Sub(rm_3b, op1, op2)
  };
  accrue_fflags(fflags);
  result_val
}

val fp_min : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> bits('m)
function fp_min(op1, op2) = {
  let (fflags, result_val) = fp_min_pure(op1, op2);
  accrue_fflags(fflags);
  result_val
}

val fp_max : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> bits('m)
function fp_max(op1, op2) = {
  let (fflags, result_val) = fp_max_pure(op1, op2);
  accrue_fflags(fflags);
  result_val
}

val fp_eq : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> bool
function fp_eq(op1, op2) = {
  let (fflags, result_val) : (bits_fflags, bool) = match 'm {
    16  => riscv_f16Eq(op1, op2),
    32  => riscv_f32Eq(op1, op2),
    64  => riscv_f64Eq(op1, op2)
  };
  accrue_fflags(fflags);
  result_val
}

val fp_gt : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> bool
function fp_gt(op1, op2) = {
  let (fflags, temp_val) : (bits_fflags, bool) = match 'm {
    16  => riscv_f16Le(op1, op2),
    32  => riscv_f32Le(op1, op2),
    64  => riscv_f64Le(op1, op2)
  };
  let result_val = (if fflags == 0b10000 then false else not(temp_val));
  accrue_fflags(fflags);
  result_val
}

val fp_ge : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> bool
function fp_ge(op1, op2) = {
  let (fflags, temp_val) : (bits_fflags, bool) = match 'm {
    16  => riscv_f16Lt(op1, op2),
    32  => riscv_f32Lt(op1, op2),
    64  => riscv_f64Lt(op1, op2)
  };
  let result_val = (if fflags == 0b10000 then false else not(temp_val));
  accrue_fflags(fflags);
  result_val
}

val fp_lt : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> bool
function fp_lt(op1, op2) = {
  let (fflags, result_val) : (bits_fflags, bool) = match 'm {
    16  => riscv_f16Lt(op1, op2),
    32  => riscv_f32Lt(op1, op2),
    64  => riscv_f64Lt(op1, op2)
  };
  accrue_fflags(fflags);
  result_val
}

val fp_le : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> bool
function fp_le(op1, op2) = {
  let (fflags, result_val) : (bits_fflags, bool) = match 'm {
    16  => riscv_f16Le(op1, op2),
    32  => riscv_f32Le(op1, op2),
    64  => riscv_f64Le(op1, op2)
  };
  accrue_fflags(fflags);
  result_val
}

val fp_mul : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m)) -> bits('m)
function fp_mul(rm_3b, op1, op2) = {
  let (fflags, result_val) : (bits_fflags, bits('m)) = match 'm {
    16  => riscv_f16Mul(rm_3b, op1, op2),
    32  => riscv_f32Mul(rm_3b, op1, op2),
    64  => riscv_f64Mul(rm_3b, op1, op2)
  };
  accrue_fflags(fflags);
  result_val
}

val fp_div : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m)) -> bits('m)
function fp_div(rm_3b, op1, op2) = {
  let (fflags, result_val) : (bits_fflags, bits('m)) = match 'm {
    16  => riscv_f16Div(rm_3b, op1, op2),
    32  => riscv_f32Div(rm_3b, op1, op2),
    64  => riscv_f64Div(rm_3b, op1, op2)
  };
  accrue_fflags(fflags);
  result_val
}

val fp_muladd : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m), bits('m)) -> bits('m)
function fp_muladd(rm_3b, op1, op2, opadd) = {
  let (fflags, result_val) : (bits_fflags, bits('m)) = match 'm {
    16  => riscv_f16MulAdd(rm_3b, op1, op2, opadd),
    32  => riscv_f32MulAdd(rm_3b, op1, op2, opadd),
    64  => riscv_f64MulAdd(rm_3b, op1, op2, opadd)
  };
  accrue_fflags(fflags);
  result_val
}

val fp_nmuladd : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m), bits('m)) -> bits('m)
function fp_nmuladd(rm_3b, op1, op2, opadd) = {
  let op1 = negate_fp(op1);
  let (fflags, result_val) : (bits_fflags, bits('m)) = match 'm {
    16  => riscv_f16MulAdd(rm_3b, op1, op2, opadd),
    32  => riscv_f32MulAdd(rm_3b, op1, op2, opadd),
    64  => riscv_f64MulAdd(rm_3b, op1, op2, opadd)
  };
  accrue_fflags(fflags);
  result_val
}

val fp_mulsub : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m), bits('m)) -> bits('m)
function fp_mulsub(rm_3b, op1, op2, opsub) = {
  let opsub = negate_fp(opsub);
  let (fflags, result_val) : (bits_fflags, bits('m)) = match 'm {
    16  => riscv_f16MulAdd(rm_3b, op1, op2, opsub),
    32  => riscv_f32MulAdd(rm_3b, op1, op2, opsub),
    64  => riscv_f64MulAdd(rm_3b, op1, op2, opsub)
  };
  accrue_fflags(fflags);
  result_val
}

val fp_nmulsub : forall 'm, 'm in {16, 32, 64}. (bits(3), bits('m), bits('m), bits('m)) -> bits('m)
function fp_nmulsub(rm_3b, op1, op2, opsub) = {
  let opsub = negate_fp(opsub);
  let op1 = negate_fp(op1);
  let (fflags, result_val) : (bits_fflags, bits('m)) = match 'm {
    16  => riscv_f16MulAdd(rm_3b, op1, op2, opsub),
    32  => riscv_f32MulAdd(rm_3b, op1, op2, opsub),
    64  => riscv_f64MulAdd(rm_3b, op1, op2, opsub)
  };
  accrue_fflags(fflags);
  result_val
}

val fp_widen : forall 'm, 'm in {16, 32}. bits('m) -> bits('m * 2)
function fp_widen(nval) = {
  let rm_3b = fcsr[FRM];
  let (fflags, wval) : (bits_fflags, bits('m * 2)) = match 'm {
    16 => riscv_f16ToF32(rm_3b, nval),
    32 => riscv_f32ToF64(rm_3b, nval)
  };
  accrue_fflags(fflags);
  wval
}

// Floating point functions without softfloat support
function riscv_f16ToI16(rm : bits_rm, v : bits_H) -> (bits_fflags, bits(16)) = {
  let (flag, sig32) = riscv_f16ToI32(rm, v);
  if signed(sig32) > signed(0b0 @ ones(15)) then (nvFlag(), 0b0 @ ones(15))
  else if signed(sig32) < signed(0b1 @ zeros(15)) then (nvFlag(), 0b1 @ zeros(15))
  else (flag, sig32[15 .. 0]);
}

function riscv_f16ToI8(rm : bits_rm, v : bits_H) -> (bits_fflags, bits(8)) = {
  let (flag, sig32) = riscv_f16ToI32(rm, v);
  if signed(sig32) > signed(0b0 @ ones(7)) then (nvFlag(), 0b0 @ ones(7))
  else if signed(sig32) < signed(0b1 @ zeros(7)) then (nvFlag(), 0b1 @ zeros(7))
  else (flag, sig32[7 .. 0]);
}

function riscv_f32ToI16(rm : bits_rm, v : bits_S) -> (bits_fflags, bits(16)) = {
  let (flag, sig32) = riscv_f32ToI32(rm, v);
  if signed(sig32) > signed(0b0 @ ones(15)) then (nvFlag(), 0b0 @ ones(15))
  else if signed(sig32) < signed(0b1 @ zeros(15)) then (nvFlag(), 0b1 @ zeros(15))
  else (flag, sig32[15 .. 0]);
}

function riscv_f16ToUi16(rm : bits_rm, v : bits_H) -> (bits_fflags, bits(16)) = {
  let (flag, sig32) = riscv_f16ToUi32(rm, v);
  if unsigned(sig32) > unsigned(ones(16)) then (nvFlag(), ones(16))
  else (flag, sig32[15 .. 0]);
}

function riscv_f16ToUi8(rm : bits_rm, v : bits_H) -> (bits_fflags, bits(8)) = {
  let (flag, sig32) = riscv_f16ToUi32(rm, v);
  if unsigned(sig32) > unsigned(ones(8)) then (nvFlag(), ones(8))
  else (flag, sig32[7 .. 0]);
}

function riscv_f32ToUi16(rm : bits_rm, v : bits_S) -> (bits_fflags, bits(16)) = {
  let (flag, sig32) = riscv_f32ToUi32(rm, v);
  if unsigned(sig32) > unsigned(ones(16)) then (nvFlag(), ones(16))
  else (flag, sig32[15 .. 0]);
}

$ifdef SYMBOLIC
// The f16-to-i16 adapter branches on overflow after the active-lane gate.
// Other narrow integer adapters retain their bitvector ITE saturation rules.
function riscv_f16ToI16_pure(rm : bits_rm, v : bits_H) -> (bits_fflags, bits(16)) = {
  let (flag, sig32) = riscv_f16ToI32(rm, v);
  let overflow = not_bool(eq_anything(sig32, sign_extend(sig32[15 .. 0])));
  let limit = ite(eq_anything(sig32[31], 0b1), 0x8000, 0x7fff);
  if overflow then (nvFlag(), limit) else (flag, sig32[15 .. 0])
}

function riscv_f16ToI8_pure(rm : bits_rm, v : bits_H) -> (bits_fflags, bits(8)) = {
  let (flag, sig32) = riscv_f16ToI32(rm, v);
  let overflow = not_bool(eq_anything(sig32, sign_extend(sig32[7 .. 0])));
  let limit = ite(eq_anything(sig32[31], 0b1), 0x80, 0x7f);
  (ite(overflow, nvFlag(), flag), ite(overflow, limit, sig32[7 .. 0]))
}

function riscv_f32ToI16_pure(rm : bits_rm, v : bits_S) -> (bits_fflags, bits(16)) = {
  let (flag, sig32) = riscv_f32ToI32(rm, v);
  let overflow = not_bool(eq_anything(sig32, sign_extend(sig32[15 .. 0])));
  let limit = ite(eq_anything(sig32[31], 0b1), 0x8000, 0x7fff);
  (ite(overflow, nvFlag(), flag), ite(overflow, limit, sig32[15 .. 0]))
}

function riscv_f16ToUi16_pure(rm : bits_rm, v : bits_H) -> (bits_fflags, bits(16)) = {
  let (flag, sig32) = riscv_f16ToUi32(rm, v);
  let overflow = not_bool(eq_anything(sig32[31 .. 16], zeros(16)));
  let limit = ones(16);
  (ite(overflow, nvFlag(), flag), ite(overflow, limit, sig32[15 .. 0]))
}

function riscv_f16ToUi8_pure(rm : bits_rm, v : bits_H) -> (bits_fflags, bits(8)) = {
  let (flag, sig32) = riscv_f16ToUi32(rm, v);
  let overflow = not_bool(eq_anything(sig32[31 .. 8], zeros(24)));
  let limit = ones(8);
  (ite(overflow, nvFlag(), flag), ite(overflow, limit, sig32[7 .. 0]))
}

function riscv_f32ToUi16_pure(rm : bits_rm, v : bits_S) -> (bits_fflags, bits(16)) = {
  let (flag, sig32) = riscv_f32ToUi32(rm, v);
  let overflow = not_bool(eq_anything(sig32[31 .. 16], zeros(16)));
  let limit = ones(16);
  (ite(overflow, nvFlag(), flag), ite(overflow, limit, sig32[15 .. 0]))
}

$endif

val rsqrt7 : forall 'm, 'm in {16, 32, 64}. (bits('m), bool) -> bits_D
function rsqrt7 (v, sub) = {
  let (sig, exp, sign, e, s) : (bits(64), bits(64), bits(1), {5, 8, 11}, {10, 23, 52}) = match 'm {
    16 => (zero_extend(64, v[9 .. 0]), zero_extend(64, v[14 .. 10]), [v[15]], 5, 10),
    32 => (zero_extend(64, v[22 .. 0]), zero_extend(64, v[30 .. 23]), [v[31]], 8, 23),
    64 => (zero_extend(64, v[51 .. 0]), zero_extend(64, v[62 .. 52]), [v[63]], 11, 52)
  };
  let table : vector(128, int) = [
      52, 51, 50, 48, 47, 46, 44, 43,
      42, 41, 40, 39, 38, 36, 35, 34,
      33, 32, 31, 30, 30, 29, 28, 27,
      26, 25, 24, 23, 23, 22, 21, 20,
      19, 19, 18, 17, 16, 16, 15, 14,
      14, 13, 12, 12, 11, 10, 10, 9,
      9, 8, 7, 7, 6, 6, 5, 4,
      4, 3, 3, 2, 2, 1, 1, 0,
      127, 125, 123, 121, 119, 118, 116, 114,
      113, 111, 109, 108, 106, 105, 103, 102,
      100, 99, 97, 96, 95, 93, 92, 91,
      90, 88, 87, 86, 85, 84, 83, 82,
      80, 79, 78, 77, 76, 75, 74, 73,
      72, 71, 70, 70, 69, 68, 67, 66,
      65, 64, 63, 63, 62, 61, 60, 59,
      59, 58, 57, 56, 56, 55, 54, 53];

  let (normalized_exp, normalized_sig) =
      if sub then {
        let nr_leadingzeros = count_leading_zeros(sig[s - 1 .. 0]);
        assert(nr_leadingzeros >= 0);
        (to_bits_unsafe(64, (0 - nr_leadingzeros)), zero_extend(64, sig[(s - 1) .. 0] << (1 + nr_leadingzeros)))
      } else {
        (exp, sig)
      };

  let idx : nat = match 'm {
    16 => unsigned([normalized_exp[0]] @ normalized_sig[9 .. 4]),
    32 => unsigned([normalized_exp[0]] @ normalized_sig[22 .. 17]),
    64 => unsigned([normalized_exp[0]] @ normalized_sig[51 .. 46])
  };
  assert(idx >= 0 & idx < 128);
  let out_sig = to_bits_unsafe(s, table[(127 - idx)]) << (s - 7);
  let out_exp = to_bits_unsafe(e, quot_round_zero(3 * (2 ^ (e - 1) - 1) - 1 - signed(normalized_exp), 2));
  zero_extend(64, sign @ out_exp @ out_sig)
}

function riscv_f16Rsqrte7(_rm : bits_rm, v : bits_H) -> (bits_fflags, bits_H) = {
  // TODO: Replace magic numbers here with `canonical_NaN()` etc.
  match float_classify(v) {
    float_class_negative_inf       => (nvFlag(), 0x7e00),
    float_class_negative_normal    => (nvFlag(), 0x7e00),
    float_class_negative_subnormal => (nvFlag(), 0x7e00),
    float_class_snan               => (nvFlag(), 0x7e00),
    float_class_qnan               => (zeros(5), 0x7e00),
    float_class_negative_zero      => (dzFlag(), 0xfc00),
    float_class_positive_zero      => (dzFlag(), 0x7c00),
    float_class_positive_inf       => (zeros(5), 0x0000),
    float_class_positive_subnormal => (zeros(5), rsqrt7(v, true)[15 .. 0]),
    float_class_positive_normal    => (zeros(5), rsqrt7(v, false)[15 .. 0])
  }
}

function riscv_f32Rsqrte7(_rm : bits_rm, v : bits_S) -> (bits_fflags, bits_S) = {
  match float_classify(v) {
    float_class_negative_inf       => (nvFlag(), 0x7fc00000),
    float_class_negative_normal    => (nvFlag(), 0x7fc00000),
    float_class_negative_subnormal => (nvFlag(), 0x7fc00000),
    float_class_snan               => (nvFlag(), 0x7fc00000),
    float_class_qnan               => (zeros(5), 0x7fc00000),
    float_class_negative_zero      => (dzFlag(), 0xff800000),
    float_class_positive_zero      => (dzFlag(), 0x7f800000),
    float_class_positive_inf       => (zeros(5), 0x00000000),
    float_class_positive_subnormal => (zeros(5), rsqrt7(v, true)[31 .. 0]),
    float_class_positive_normal    => (zeros(5), rsqrt7(v, false)[31 .. 0])
  }
}

function riscv_f64Rsqrte7(_rm : bits_rm, v : bits_D) -> (bits_fflags, bits_D) = {
  match float_classify(v) {
    float_class_negative_inf       => (nvFlag(), 0x7ff8000000000000),
    float_class_negative_normal    => (nvFlag(), 0x7ff8000000000000),
    float_class_negative_subnormal => (nvFlag(), 0x7ff8000000000000),
    float_class_snan               => (nvFlag(), 0x7ff8000000000000),
    float_class_qnan               => (zeros(5), 0x7ff8000000000000),
    float_class_negative_zero      => (dzFlag(), 0xfff0000000000000),
    float_class_positive_zero      => (dzFlag(), 0x7ff0000000000000),
    float_class_positive_inf       => (zeros(5), zeros(64)),
    float_class_positive_subnormal => (zeros(5), rsqrt7(v, true)[63 .. 0]),
    float_class_positive_normal    => (zeros(5), rsqrt7(v, false)[63 .. 0])
  }
}

val recip7 : forall 'm, 'm in {16, 32, 64}. (bits('m), bits(3), bool) -> (bool, bits_D)
function recip7 (v, rm_3b, sub) = {
  let (sig, exp, sign, e, s) : (bits(64), bits(64), bits(1), {5, 8, 11}, {10, 23, 52}) = match 'm {
    16 => (zero_extend(64, v[9 .. 0]), zero_extend(64, v[14 .. 10]), [v[15]], 5, 10),
    32 => (zero_extend(64, v[22 .. 0]), zero_extend(64, v[30 .. 23]), [v[31]], 8, 23),
    64 => (zero_extend(64, v[51 .. 0]), zero_extend(64, v[62 .. 52]), [v[63]], 11, 52)
  };
  let table : vector(128, int) = [
      127, 125, 123, 121, 119, 117, 116, 114,
      112, 110, 109, 107, 105, 104, 102, 100,
      99, 97, 96, 94, 93, 91, 90, 88,
      87, 85, 84, 83, 81, 80, 79, 77,
      76, 75, 74, 72, 71, 70, 69, 68,
      66, 65, 64, 63, 62, 61, 60, 59,
      58, 57, 56, 55, 54, 53, 52, 51,
      50, 49, 48, 47, 46, 45, 44, 43,
      42, 41, 40, 40, 39, 38, 37, 36,
      35, 35, 34, 33, 32, 31, 31, 30,
      29, 28, 28, 27, 26, 25, 25, 24,
      23, 23, 22, 21, 21, 20, 19, 19,
      18, 17, 17, 16, 15, 15, 14, 14,
      13, 12, 12, 11, 11, 10, 9, 9,
      8, 8, 7, 7, 6, 5, 5, 4,
      4, 3, 3, 2, 2, 1, 1, 0];

  let nr_leadingzeros = count_leading_zeros(sig[s - 1 .. 0]);
  assert(nr_leadingzeros >= 0);
  let (normalized_exp, normalized_sig) =
      if sub then {
        (to_bits_unsafe(64, (0 - nr_leadingzeros)), zero_extend(64, sig[(s - 1) .. 0] << (1 + nr_leadingzeros)))
      } else {
        (exp, sig)
      };

  let idx : nat = match 'm {
    16 => unsigned(normalized_sig[9 .. 3]),
    32 => unsigned(normalized_sig[22 .. 16]),
    64 => unsigned(normalized_sig[51 .. 45])
  };
  assert(idx >= 0 & idx < 128);
  let mid_exp = to_bits_unsafe(e, 2 * (2 ^ (e - 1) - 1) - 1 - signed(normalized_exp));
  let mid_sig = to_bits_unsafe(s, table[(127 - idx)]) << (s - 7);

  let (out_exp, out_sig)=
      if mid_exp == zeros(e) then {
        (mid_exp, mid_sig >> 1 | 0b1 @ zeros(s - 1))
      } else if mid_exp == ones(e) then {
        (zeros(e), mid_sig >> 2 | 0b01 @ zeros(s - 2))
      } else (mid_exp, mid_sig);

  if sub & nr_leadingzeros > 1 then {
      if (rm_3b == 0b001 | rm_3b == 0b010 & sign == 0b0 | rm_3b == 0b011 & sign == 0b1) then {
        (true, zero_extend(64, sign @ ones(e - 1) @ 0b0 @ ones(s)))
      }
      else (true, zero_extend(64, sign @ ones(e) @ zeros(s)))
    } else (false, zero_extend(64, sign @ out_exp @ out_sig))
}

function riscv_f16Recip7(rm : bits_rm, v : bits_H) -> (bits_fflags, bits_H) = {
  let (round_abnormal_true, res_true) = recip7(v, rm, true);
  let (round_abnormal_false, res_false) = recip7(v, rm, false);
  match float_classify(v) {
    float_class_negative_inf       => (zeros(5), 0x8000),
    float_class_positive_inf       => (zeros(5), 0x0000),
    float_class_negative_zero      => (dzFlag(), 0xfc00),
    float_class_positive_zero      => (dzFlag(), 0x7c00),
    float_class_snan               => (nvFlag(), 0x7e00),
    float_class_qnan               => (zeros(5), 0x7e00),
    float_class_negative_subnormal => if round_abnormal_true then (nxFlag() | ofFlag(), res_true[15 .. 0]) else (zeros(5), res_true[15 .. 0]),
    float_class_positive_subnormal => if round_abnormal_true then (nxFlag() | ofFlag(), res_true[15 .. 0]) else (zeros(5), res_true[15 .. 0]),
    _                              => if round_abnormal_false then (nxFlag() | ofFlag(), res_false[15 .. 0]) else (zeros(5), res_false[15 .. 0])
  }
}

function riscv_f32Recip7(rm : bits_rm, v : bits_S) -> (bits_fflags, bits_S) = {
  let (round_abnormal_true, res_true) = recip7(v, rm, true);
  let (round_abnormal_false, res_false) = recip7(v, rm, false);
  match float_classify(v) {
    float_class_negative_inf       => (zeros(5), 0x80000000),
    float_class_positive_inf       => (zeros(5), 0x00000000),
    float_class_negative_zero      => (dzFlag(), 0xff800000),
    float_class_positive_zero      => (dzFlag(), 0x7f800000),
    float_class_snan               => (nvFlag(), 0x7fc00000),
    float_class_qnan               => (zeros(5), 0x7fc00000),
    float_class_negative_subnormal => if round_abnormal_true then (nxFlag() | ofFlag(), res_true[31 .. 0]) else (zeros(5), res_true[31 .. 0]),
    float_class_positive_subnormal => if round_abnormal_true then (nxFlag() | ofFlag(), res_true[31 .. 0]) else (zeros(5), res_true[31 .. 0]),
    _                              => if round_abnormal_false then (nxFlag() | ofFlag(), res_false[31 .. 0]) else (zeros(5), res_false[31 .. 0])
  }
}

function riscv_f64Recip7(rm : bits_rm, v : bits_D) ->  (bits_fflags, bits_D) = {
  let (round_abnormal_true, res_true) = recip7(v, rm, true);
  let (round_abnormal_false, res_false) = recip7(v, rm, false);
  match float_classify(v) {
    float_class_negative_inf       => (zeros(5), 0x8000000000000000),
    float_class_positive_inf       => (zeros(5), 0x0000000000000000),
    float_class_negative_zero      => (dzFlag(), 0xfff0000000000000),
    float_class_positive_zero      => (dzFlag(), 0x7ff0000000000000),
    float_class_snan               => (nvFlag(), 0x7ff8000000000000),
    float_class_qnan               => (zeros(5), 0x7ff8000000000000),
    float_class_negative_subnormal => if round_abnormal_true then (nxFlag() | ofFlag(), res_true[63 .. 0]) else (zeros(5), res_true[63 .. 0]),
    float_class_positive_subnormal => if round_abnormal_true then (nxFlag() | ofFlag(), res_true[63 .. 0]) else (zeros(5), res_true[63 .. 0]),
    _                              => if round_abnormal_false then (nxFlag() | ofFlag(), res_false[63 .. 0]) else (zeros(5), res_false[63 .. 0])
  }
}
