// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

$ifdef SYMBOLIC
$ifdef SYMBOLIC_EXTRA_OPS
register __isla_use_extra_ops : bool = true
$else
register __isla_use_extra_ops : bool = false
$endif

val isla_carryless_mul = pure "isla_carryless_mul" : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits(2 * 'n)
val isla_carryless_mulr = pure "isla_carryless_mulr" : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
val isla_clmul = pure "isla_clmul" : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
val isla_clmulh = pure "isla_clmulh" : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
val isla_mul_low = pure "isla_mul_low" : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
val isla_divu = pure "isla_divu" : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
val isla_divs = pure "isla_divs" : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
val isla_gcm_mul = pure "isla_gcm_mul" : (bits(128), bits(128)) -> bits(128)
val isla_aes_subbytes_fwd = pure "isla_aes_subbytes_fwd" : bits(128) -> bits(128)
val isla_aes_subbytes_inv = pure "isla_aes_subbytes_inv" : bits(128) -> bits(128)
val isla_aes_mixcolumns_fwd = pure "isla_aes_mixcolumns_fwd" : forall 'n, 'n in {32, 64, 128}. bits('n) -> bits('n)
val isla_aes_mixcolumns_inv = pure "isla_aes_mixcolumns_inv" : forall 'n, 'n in {32, 64, 128}. bits('n) -> bits('n)
val isla_sm4_key_schedule = pure "isla_sm4_key_schedule" : (bits(128), bits(5)) -> bits(128)
val isla_aes_key_schedule_128 = pure "isla_aes_key_schedule_128" : (bits(128), bits(4)) -> bits(128)
val isla_aes_key_schedule_256 = pure "isla_aes_key_schedule_256" : (bits(128), bits(128), bits(4)) -> bits(128)
val isla_count_ones = pure "isla_count_ones" : forall 'n, 'n >= 0. bits('n) -> range(0, 'n)
val isla_count_leading_zeros_bits = pure "isla_count_leading_zeros_bits" : forall 'n, 'n >= 0. bits('n) -> bits('n)
val isla_count_trailing_zeros_bits = pure "isla_count_trailing_zeros_bits" : forall 'n, 'n >= 0. bits('n) -> bits('n)
val isla_first_set_bit = pure "isla_first_set_bit" : forall 'n, 'n > 0. bits('n) -> bits('n)
val isla_low_bits = pure "isla_low_bits" : forall 'n 'm, 'm > 0. (int('m), bits('n)) -> bits('m)
val isla_low_half = pure "isla_low_half" : forall 'n, 'n > 0. bits(2 * 'n) -> bits('n)
val isla_narrowing_shift_amount = pure "isla_narrowing_shift_amount" : forall 'n, 'n > 0. bits('n) -> nat
val isla_zero_extend_one = pure "isla_zero_extend_one" : forall 'n, 'n > 0. bits('n) -> bits('n + 1)
val isla_sign_extend_one = pure "isla_sign_extend_one" : forall 'n, 'n > 0. bits('n) -> bits('n + 1)
val isla_low_half_plus_one = pure "isla_low_half_plus_one" : forall 'n, 'n > 0. bits(2 * 'n) -> bits('n + 1)
val isla_shift_amount_bits = pure "isla_shift_amount_bits" : forall 'n, 'n > 1. bits('n) -> bits('n)
val isla_add_bit = pure "isla_add_bit" : forall 'n, 'n > 0. (bits('n), bits(1)) -> bits('n)
val isla_fixed_rounding_incr = pure "isla_fixed_rounding_incr" : forall 'm 'n, 'm > 0 & 'n >= 0. (bits('m), int('n), bits(2)) -> bits(1)
val isla_unsigned_saturation_result = pure "isla_unsigned_saturation_result" : forall 'n 'm, 'n >= 'm & 'm > 1. (int('m), bits('n)) -> bits('m)
val isla_unsigned_saturation_flag = pure "isla_unsigned_saturation_flag" : forall 'n 'm, 'n >= 'm & 'm > 1. (int('m), bits('n)) -> bits(1)
val isla_signed_saturation_result = pure "isla_signed_saturation_result" : forall 'n 'm, 'n >= 'm & 'm > 1. (int('m), bits('n)) -> bits('m)
val isla_signed_saturation_flag = pure "isla_signed_saturation_flag" : forall 'n 'm, 'n >= 'm & 'm > 1. (int('m), bits('n)) -> bits(1)
val isla_unsigned_saturation_half_result = pure "isla_unsigned_saturation_half_result" : forall 'n, 'n > 1. bits(2 * 'n) -> bits('n)
val isla_unsigned_saturation_half_flag = pure "isla_unsigned_saturation_half_flag" : forall 'n, 'n > 1. bits(2 * 'n) -> bits(1)
val isla_signed_saturation_half_result = pure "isla_signed_saturation_half_result" : forall 'n, 'n > 1. bits(2 * 'n) -> bits('n)
val isla_signed_saturation_half_flag = pure "isla_signed_saturation_half_flag" : forall 'n, 'n > 1. bits(2 * 'n) -> bits(1)
val isla_unsigned_saturation_narrow1_result = pure "isla_unsigned_saturation_narrow1_result" : forall 'n, 'n > 2. bits('n) -> bits('n - 1)
val isla_unsigned_saturation_narrow1_flag = pure "isla_unsigned_saturation_narrow1_flag" : forall 'n, 'n > 2. bits('n) -> bits(1)
val isla_signed_saturation_narrow1_result = pure "isla_signed_saturation_narrow1_result" : forall 'n, 'n > 2. bits('n) -> bits('n - 1)
val isla_signed_saturation_narrow1_flag = pure "isla_signed_saturation_narrow1_flag" : forall 'n, 'n > 2. bits('n) -> bits(1)
val isla_set_low_bits = pure "isla_set_low_bits" : forall 'n 'm, 'm > 0. (int('m), bits('n), bits('m)) -> bits('n)
val isla_widen_unsigned = pure "isla_widen_unsigned" : forall 'n, 'n > 0. bits('n) -> bits(2 * 'n)
val isla_widen_signed = pure "isla_widen_signed" : forall 'n, 'n > 0. bits('n) -> bits(2 * 'n)
val isla_arith_shiftr = pure "arith_shiftr" : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
val isla_rotate_left = pure "isla_rotate_left" : forall 'n 'm, 'n > 0 & 'm >= 0 & 'n >= 2 ^ 'm. (bits('n), bits('m)) -> bits('n)
val isla_rotate_right = pure "isla_rotate_right" : forall 'n 'm, 'n > 0 & 'm >= 0 & 'n >= 2 ^ 'm. (bits('n), bits('m)) -> bits('n)
val isla_mux2 = pure "isla_mux2" : forall 'n, 'n > 0. (bits(1), bits('n), bits('n)) -> bits('n)
val isla_brev8 = pure "isla_brev8" : forall 'm, 'm >= 0 & mod('m, 8) == 0. bits('m) -> bits('m)
val isla_reverse_bits = pure "isla_reverse_bits" : forall 'n, 'n > 0. bits('n) -> bits('n)
val isla_bool_to_bit = pure "one_if" : bool -> bits(1)
val isla_vwredsumu = pure "isla_vwredsumu" : forall 'n 'm, 'n > 0 & 'm > 0. (bits('n), bits(2 * 'm), vector('n, bits('m))) -> bits(2 * 'm)
val isla_vwredsum = pure "isla_vwredsum" : forall 'n 'm, 'n > 0 & 'm > 0. (bits('n), bits(2 * 'm), vector('n, bits('m))) -> bits(2 * 'm)
$endif

$ifndef SYMBOLIC
function isla_bool_to_bit_or_default(x : bool) -> bits(1) = bool_to_bit(x)
$else
function isla_bool_to_bit_or_default(x : bool) -> bits(1) =
  if __isla_use_extra_ops then isla_bool_to_bit(x)
  else bool_to_bit(x)
$endif

// Reverse bits in each byte
$ifndef SYMBOLIC
val brev8 : forall 'm, 'm >= 0 & mod('m, 8) == 0. (bits('m)) -> bits('m)
function brev8(input) = {
  var output : bits('m) = zeros();
  foreach (i from 0 to ('m - 8) by 8)
    output[i+7..i] = reverse_bits(input[i+7..i]);
  output
}
$else
val brev8_default : forall 'm, 'm >= 0 & mod('m, 8) == 0. (bits('m)) -> bits('m)
function brev8_default(input) = {
  var output : bits('m) = zeros();
  foreach (i from 0 to ('m - 8) by 8)
    output[i+7..i] = reverse_bits(input[i+7..i]);
  output
}

val brev8 : forall 'm, 'm >= 0 & mod('m, 8) == 0. (bits('m)) -> bits('m)
function brev8(input) = if __isla_use_extra_ops then isla_brev8(input) else brev8_default(input)
$endif

// Carry-less multiply.
$ifndef SYMBOLIC
val carryless_mul : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits(2 * 'n)
function carryless_mul(a, b) = {
  var result : bits(2 * 'n) = zeros();
  foreach (i from 0 to ('n - 1)) {
    if   a[i] == 0b1
    then result = result ^ (zero_extend(b) << i);
  };
  result
}
$else
val carryless_mul_default : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits(2 * 'n)
function carryless_mul_default(a, b) = {
  var result : bits(2 * 'n) = zeros();
  foreach (i from 0 to ('n - 1)) {
    if   a[i] == 0b1
    then result = result ^ (zero_extend(b) << i);
  };
  result
}

val carryless_mul : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits(2 * 'n)
function carryless_mul(a, b) =
  if __isla_use_extra_ops then isla_carryless_mul(a, b)
  else carryless_mul_default(a, b)
$endif

// Reverse carry-less multiply.
$ifndef SYMBOLIC
val carryless_mulr : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
function carryless_mulr(a, b) = {
  var result : bits('n) = zeros();
  foreach (i from 0 to ('n - 1)) {
    if   a[i] == 0b1
    then result = result ^ (b >> ('n - i - 1));
  };
  result
}
$else
val carryless_mulr_default : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
function carryless_mulr_default(a, b) = {
  var result : bits('n) = zeros();
  foreach (i from 0 to ('n - 1)) {
    if   a[i] == 0b1
    then result = result ^ (b >> ('n - i - 1));
  };
  result
}

val carryless_mulr : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
function carryless_mulr(a, b) =
  if __isla_use_extra_ops then isla_carryless_mulr(a, b)
  else carryless_mulr_default(a, b)
$endif

// Equivalent reverse carry-less multiply.
private val carryless_mul_reversed : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
function carryless_mul_reversed(a, b) = {
  let prod = carryless_mul(reverse_bits(a), reverse_bits(b));
  reverse_bits(prod['n - 1 .. 0])
}

val mult_to_bits_half : forall 'l, 'l > 0 . (implicit('l), Signedness, Signedness, bits('l), bits('l), VectorHalf) -> bits('l)
$ifndef SYMBOLIC
function mult_to_bits_half(l, sign1, sign2, rs1_bits, rs2_bits, result_part) = {
  let rs1_int : int = match sign1 {
    Signed   => signed(rs1_bits),
    Unsigned => unsigned(rs1_bits),
  };
  let rs2_int : int = match sign2 {
    Signed   => signed(rs2_bits),
    Unsigned => unsigned(rs2_bits),
  };

  let result_wide = to_bits_truncate(2 * l, rs1_int * rs2_int);
  match result_part {
    High => result_wide[(2 * l - 1) .. l],
    Low  => result_wide[(l - 1) .. 0],
  }
}
$else
val mult_to_bits_half_default : forall 'l, 'l > 0 . (implicit('l), Signedness, Signedness, bits('l), bits('l), VectorHalf) -> bits('l)
function mult_to_bits_half_default(l, sign1, sign2, rs1_bits, rs2_bits, result_part) = {
  let rs1_int : int = match sign1 {
    Signed   => signed(rs1_bits),
    Unsigned => unsigned(rs1_bits),
  };
  let rs2_int : int = match sign2 {
    Signed   => signed(rs2_bits),
    Unsigned => unsigned(rs2_bits),
  };

  let result_wide = to_bits_truncate(2 * l, rs1_int * rs2_int);
  match result_part {
    High => result_wide[(2 * l - 1) .. l],
    Low  => result_wide[(l - 1) .. 0],
  }
}

function mult_to_bits_half(l, sign1, sign2, rs1_bits, rs2_bits, result_part) =
  if __isla_use_extra_ops & result_part == Low
  then isla_mul_low(rs1_bits, rs2_bits)
  else mult_to_bits_half_default(l, sign1, sign2, rs1_bits, rs2_bits, result_part)
$endif

$[property]
function cmulr_equivalence(a : bits(16), b : bits(16)) -> bool = {
  carryless_mul_reversed(a, b) == carryless_mulr(a, b)
}

val rev8 : forall 'm, 'm >= 0 & mod('m, 8) == 0. (bits('m)) -> bits('m)
function rev8(input) = {
  var output : bits('m) = zeros();
  foreach (i from 0 to ('m - 8) by 8) {
    output[(i + 7)..i] = input[('m - i - 1) .. ('m - i - 8)];
  };
  output
}

$ifndef SYMBOLIC
val count_ones : forall 'n, 'n >= 0. (bits('n)) -> range(0, 'n)
function count_ones(x) = {
  var count : range(0, 'n) = 0;
  foreach (i from 0 to ('n - 1)) {
    if x[i] == 0b1 then {
      let new_count = count + 1;
      assert(new_count <= 'n);
      count = new_count;
    }
  };
  count
}
$else
val count_ones_default : forall 'n, 'n >= 0. (bits('n)) -> range(0, 'n)
function count_ones_default(x) = {
  var count : range(0, 'n) = 0;
  foreach (i from 0 to ('n - 1)) {
    if x[i] == 0b1 then {
      let new_count = count + 1;
      assert(new_count <= 'n);
      count = new_count;
    }
  };
  count
}

val count_ones : forall 'n, 'n >= 0. (bits('n)) -> range(0, 'n)
function count_ones(x) =
  if __isla_use_extra_ops then isla_count_ones(x)
  else count_ones_default(x)
$endif
