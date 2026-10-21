
val fp_min_pure : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> (bits_fflags, bits('m))
function fp_min_pure(op1, op2) = {
  let (fflags, op1_lt_op2) : (bits_fflags, bool) = match 'm {
    16 => riscv_f16Lt_quiet(op1, op2),
    32 => riscv_f32Lt_quiet(op1, op2),
    64 => riscv_f64Lt_quiet(op1, op2)
  };
  let op1_nan = ieee_is_nan(op1);
  let op2_nan = ieee_is_nan(op2);
  let op1_neg_zero = eq_anything(op1, 0b1 @ zeros('m - 1));
  let op2_neg_zero = eq_anything(op2, 0b1 @ zeros('m - 1));
  let op1_pos_zero = eq_anything(op1, zeros('m));
  let op2_pos_zero = eq_anything(op2, zeros('m));
  let result_val = ite(strict_and_bool(op1_nan, op2_nan), canonical_NaN('m),
    ite(op1_nan, op2,
      ite(op2_nan, op1,
        ite(strict_and_bool(op1_neg_zero, op2_pos_zero), op1,
          ite(strict_and_bool(op2_neg_zero, op1_pos_zero), op2,
            ite(op1_lt_op2, op1, op2))))));
  (fflags, result_val)
}

val fp_max_pure : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> (bits_fflags, bits('m))
function fp_max_pure(op1, op2) = {
  let (fflags, op1_lt_op2) : (bits_fflags, bool) = match 'm {
    16 => riscv_f16Lt_quiet(op1, op2),
    32 => riscv_f32Lt_quiet(op1, op2),
    64 => riscv_f64Lt_quiet(op1, op2)
  };
  let op1_nan = ieee_is_nan(op1);
  let op2_nan = ieee_is_nan(op2);
  let op1_neg_zero = eq_anything(op1, 0b1 @ zeros('m - 1));
  let op2_neg_zero = eq_anything(op2, 0b1 @ zeros('m - 1));
  let op1_pos_zero = eq_anything(op1, zeros('m));
  let op2_pos_zero = eq_anything(op2, zeros('m));
  let result_val = ite(strict_and_bool(op1_nan, op2_nan), canonical_NaN('m),
    ite(op1_nan, op2,
      ite(op2_nan, op1,
        ite(strict_and_bool(op1_neg_zero, op2_pos_zero), op2,
          ite(strict_and_bool(op2_neg_zero, op1_pos_zero), op1,
            ite(op1_lt_op2, op2, op1))))));
  (fflags, result_val)
}

val fp_minm_pure : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> (bits_fflags, bits('m))
function fp_minm_pure(op1, op2) = {
  let (fflags, result_val) = fp_min_pure(op1, op2);
  (fflags, ite(strict_or_bool(ieee_is_nan(op1), ieee_is_nan(op2)), canonical_NaN('m), result_val))
}

val fp_maxm_pure : forall 'm, 'm in {16, 32, 64}. (bits('m), bits('m)) -> (bits_fflags, bits('m))
function fp_maxm_pure(op1, op2) = {
  let (fflags, result_val) = fp_max_pure(op1, op2);
  (fflags, ite(strict_or_bool(ieee_is_nan(op1), ieee_is_nan(op2)), canonical_NaN('m), result_val))
}

