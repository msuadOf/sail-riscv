// Isolated IEEE exception probes: outputs use the RISC-V flag order only
// for convenient comparison with the SoftFloat oracle, not inside the library.
$ifdef SYMBOLIC
function ieee_probe_rm(raw : bits(3)) -> float_rounding_mode =
  ite(raw == 0b001, round_toward_zero(),
    ite(raw == 0b010, round_toward_negative(),
      ite(raw == 0b011, round_toward_positive(),
        ite(raw == 0b100, round_nearest_ties_to_away(), round_nearest_ties_to_even()))))

function ieee_probe_flags(e : ieee_fp_exceptions) -> bits(5) =
  isla_bool_to_bit(ieee_has_invalid(e)) @
  isla_bool_to_bit(ieee_has_divide_by_zero(e)) @
  isla_bool_to_bit(ieee_has_overflow(e)) @
  isla_bool_to_bit(ieee_has_underflow(e)) @
  isla_bool_to_bit(ieee_has_inexact(e))

function ieee_add16_probe(rm_bits : bits(3), a : bits(16), b : bits(16)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp16_add(rm, fp16_from_ieee(a), fp16_from_ieee(b));
  let flags = ieee_add16_exceptions(rm, a, b, result);
  (ieee_probe_flags(flags), fp16_to_ieee(result))
}

function ieee_sub16_probe(rm_bits : bits(3), a : bits(16), b : bits(16)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp16_sub(rm, fp16_from_ieee(a), fp16_from_ieee(b));
  let flags = ieee_sub16_exceptions(rm, a, b, result);
  (ieee_probe_flags(flags), fp16_to_ieee(result))
}

function ieee_mul16_probe(rm_bits : bits(3), a : bits(16), b : bits(16)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp16_mul(rm, fp16_from_ieee(a), fp16_from_ieee(b));
  let flags = ieee_mul16_exceptions(rm, a, b, result);
  (ieee_probe_flags(flags), fp16_to_ieee(result))
}

function ieee_div16_probe(rm_bits : bits(3), a : bits(16), b : bits(16)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp16_div(rm, fp16_from_ieee(a), fp16_from_ieee(b));
  let flags = ieee_div16_exceptions(rm, a, b, result);
  (ieee_probe_flags(flags), fp16_to_ieee(result))
}

function ieee_sqrt16_probe(rm_bits : bits(3), a : bits(16)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp16_sqrt(rm, fp16_from_ieee(a));
  let flags = ieee_sqrt16_exceptions(rm, a, result);
  (ieee_probe_flags(flags), fp16_to_ieee(result))
}

function ieee_fma16_probe(rm_bits : bits(3), a : bits(16), b : bits(16), c : bits(16)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp16_fma(rm, fp16_from_ieee(a), fp16_from_ieee(b), fp16_from_ieee(c));
  let flags = ieee_fma16_exceptions(rm, a, b, c, result);
  (ieee_probe_flags(flags), fp16_to_ieee(result))
}

function ieee_add32_probe(rm_bits : bits(3), a : bits(32), b : bits(32)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp32_add(rm, fp32_from_ieee(a), fp32_from_ieee(b));
  let flags = ieee_add32_exceptions(rm, a, b, result);
  (ieee_probe_flags(flags), fp32_to_ieee(result))
}

function ieee_sub32_probe(rm_bits : bits(3), a : bits(32), b : bits(32)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp32_sub(rm, fp32_from_ieee(a), fp32_from_ieee(b));
  let flags = ieee_sub32_exceptions(rm, a, b, result);
  (ieee_probe_flags(flags), fp32_to_ieee(result))
}

function ieee_mul32_probe(rm_bits : bits(3), a : bits(32), b : bits(32)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp32_mul(rm, fp32_from_ieee(a), fp32_from_ieee(b));
  let flags = ieee_mul32_exceptions(rm, a, b, result);
  (ieee_probe_flags(flags), fp32_to_ieee(result))
}

function ieee_div32_probe(rm_bits : bits(3), a : bits(32), b : bits(32)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp32_div(rm, fp32_from_ieee(a), fp32_from_ieee(b));
  let flags = ieee_div32_exceptions(rm, a, b, result);
  (ieee_probe_flags(flags), fp32_to_ieee(result))
}

function ieee_sqrt32_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp32_sqrt(rm, fp32_from_ieee(a));
  let flags = ieee_sqrt32_exceptions(rm, a, result);
  (ieee_probe_flags(flags), fp32_to_ieee(result))
}

function ieee_fma32_probe(rm_bits : bits(3), a : bits(32), b : bits(32), c : bits(32)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp32_fma(rm, fp32_from_ieee(a), fp32_from_ieee(b), fp32_from_ieee(c));
  let flags = ieee_fma32_exceptions(rm, a, b, c, result);
  (ieee_probe_flags(flags), fp32_to_ieee(result))
}

function ieee_add64_probe(rm_bits : bits(3), a : bits(64), b : bits(64)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp64_add(rm, fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_add64_exceptions(rm, a, b, result);
  (ieee_probe_flags(flags), fp64_to_ieee(result))
}

function ieee_sub64_probe(rm_bits : bits(3), a : bits(64), b : bits(64)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp64_sub(rm, fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_sub64_exceptions(rm, a, b, result);
  (ieee_probe_flags(flags), fp64_to_ieee(result))
}

function ieee_mul64_probe(rm_bits : bits(3), a : bits(64), b : bits(64)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp64_mul(rm, fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_mul64_exceptions(rm, a, b, result);
  (ieee_probe_flags(flags), fp64_to_ieee(result))
}

function ieee_div64_probe(rm_bits : bits(3), a : bits(64), b : bits(64)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp64_div(rm, fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_div64_exceptions(rm, a, b, result);
  (ieee_probe_flags(flags), fp64_to_ieee(result))
}

function ieee_sqrt64_probe(rm_bits : bits(3), a : bits(64)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp64_sqrt(rm, fp64_from_ieee(a));
  let flags = ieee_sqrt64_exceptions(rm, a, result);
  (ieee_probe_flags(flags), fp64_to_ieee(result))
}

function ieee_fma64_probe(rm_bits : bits(3), a : bits(64), b : bits(64), c : bits(64)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp64_fma(rm, fp64_from_ieee(a), fp64_from_ieee(b), fp64_from_ieee(c));
  let flags = ieee_fma64_exceptions(rm, a, b, c, result);
  (ieee_probe_flags(flags), fp64_to_ieee(result))
}
function ieee_eq16_probe(a : bits(16), b : bits(16)) -> (bits(5), bits(1)) = {
  let result = fp16_eq(fp16_from_ieee(a), fp16_from_ieee(b));
  let flags = ieee_eq16_exceptions(a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_eq_signaling16_probe(a : bits(16), b : bits(16)) -> (bits(5), bits(1)) = {
  let result = fp16_eq(fp16_from_ieee(a), fp16_from_ieee(b));
  let flags = ieee_lt16_exceptions(true, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_lt16_probe(a : bits(16), b : bits(16)) -> (bits(5), bits(1)) = {
  let result = fp16_lt(fp16_from_ieee(a), fp16_from_ieee(b));
  let flags = ieee_lt16_exceptions(true, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_lt_quiet16_probe(a : bits(16), b : bits(16)) -> (bits(5), bits(1)) = {
  let result = fp16_lt(fp16_from_ieee(a), fp16_from_ieee(b));
  let flags = ieee_lt16_exceptions(false, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_le16_probe(a : bits(16), b : bits(16)) -> (bits(5), bits(1)) = {
  let result = fp16_lteq(fp16_from_ieee(a), fp16_from_ieee(b));
  let flags = ieee_lt16_exceptions(true, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_le_quiet16_probe(a : bits(16), b : bits(16)) -> (bits(5), bits(1)) = {
  let result = fp16_lteq(fp16_from_ieee(a), fp16_from_ieee(b));
  let flags = ieee_lt16_exceptions(false, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_eq32_probe(a : bits(32), b : bits(32)) -> (bits(5), bits(1)) = {
  let result = fp32_eq(fp32_from_ieee(a), fp32_from_ieee(b));
  let flags = ieee_eq32_exceptions(a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_eq_signaling32_probe(a : bits(32), b : bits(32)) -> (bits(5), bits(1)) = {
  let result = fp32_eq(fp32_from_ieee(a), fp32_from_ieee(b));
  let flags = ieee_lt32_exceptions(true, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_lt32_probe(a : bits(32), b : bits(32)) -> (bits(5), bits(1)) = {
  let result = fp32_lt(fp32_from_ieee(a), fp32_from_ieee(b));
  let flags = ieee_lt32_exceptions(true, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_lt_quiet32_probe(a : bits(32), b : bits(32)) -> (bits(5), bits(1)) = {
  let result = fp32_lt(fp32_from_ieee(a), fp32_from_ieee(b));
  let flags = ieee_lt32_exceptions(false, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_le32_probe(a : bits(32), b : bits(32)) -> (bits(5), bits(1)) = {
  let result = fp32_lteq(fp32_from_ieee(a), fp32_from_ieee(b));
  let flags = ieee_lt32_exceptions(true, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_le_quiet32_probe(a : bits(32), b : bits(32)) -> (bits(5), bits(1)) = {
  let result = fp32_lteq(fp32_from_ieee(a), fp32_from_ieee(b));
  let flags = ieee_lt32_exceptions(false, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_eq64_probe(a : bits(64), b : bits(64)) -> (bits(5), bits(1)) = {
  let result = fp64_eq(fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_eq64_exceptions(a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_eq_signaling64_probe(a : bits(64), b : bits(64)) -> (bits(5), bits(1)) = {
  let result = fp64_eq(fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_lt64_exceptions(true, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_lt64_probe(a : bits(64), b : bits(64)) -> (bits(5), bits(1)) = {
  let result = fp64_lt(fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_lt64_exceptions(true, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_lt_quiet64_probe(a : bits(64), b : bits(64)) -> (bits(5), bits(1)) = {
  let result = fp64_lt(fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_lt64_exceptions(false, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_le64_probe(a : bits(64), b : bits(64)) -> (bits(5), bits(1)) = {
  let result = fp64_lteq(fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_lt64_exceptions(true, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}

function ieee_le_quiet64_probe(a : bits(64), b : bits(64)) -> (bits(5), bits(1)) = {
  let result = fp64_lteq(fp64_from_ieee(a), fp64_from_ieee(b));
  let flags = ieee_lt64_exceptions(false, a, b);
  (ieee_probe_flags(flags), isla_bool_to_bit(result))
}
function ieee_round16_probe(rm_bits : bits(3), a : bits(16), exact_bits : bits(1)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp16_round_to_integral(rm, fp16_from_ieee(a));
  let flags = ieee_round16_exceptions(a, result, exact_bits == 0b1);
  (ieee_probe_flags(flags), fp16_to_ieee(result))
}

function ieee_fp16_to_i32_probe(rm_bits : bits(3), a : bits(16)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let rounded = fp16_round_to_integral(rm, fp16_from_ieee(a));
  let flags = ieee_fp16_to_int_exceptions(a, rounded, false, false);
  let candidate = fp16_to_signed32(round_toward_zero(), rounded);
  (ieee_probe_flags(flags), candidate)
}

function ieee_i32_to_fp16_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp16_from_signed(rm, a);
  let flags = ieee_int32_to_fp16_exceptions(rm, a, false, result);
  (ieee_probe_flags(flags), fp16_to_ieee(result))
}

function ieee_fp16_to_u32_probe(rm_bits : bits(3), a : bits(16)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let rounded = fp16_round_to_integral(rm, fp16_from_ieee(a));
  let flags = ieee_fp16_to_int_exceptions(a, rounded, true, false);
  let candidate = fp16_to_unsigned32(round_toward_zero(), rounded);
  (ieee_probe_flags(flags), candidate)
}

function ieee_u32_to_fp16_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp16_from_unsigned(rm, a);
  let flags = ieee_int32_to_fp16_exceptions(rm, a, true, result);
  (ieee_probe_flags(flags), fp16_to_ieee(result))
}

function ieee_fp16_to_i64_probe(rm_bits : bits(3), a : bits(16)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let rounded = fp16_round_to_integral(rm, fp16_from_ieee(a));
  let flags = ieee_fp16_to_int_exceptions(a, rounded, false, true);
  let candidate = fp16_to_signed64(round_toward_zero(), rounded);
  (ieee_probe_flags(flags), candidate)
}

function ieee_i64_to_fp16_probe(rm_bits : bits(3), a : bits(64)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp16_from_signed(rm, a);
  let flags = ieee_int64_to_fp16_exceptions(rm, a, false, result);
  (ieee_probe_flags(flags), fp16_to_ieee(result))
}

function ieee_fp16_to_u64_probe(rm_bits : bits(3), a : bits(16)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let rounded = fp16_round_to_integral(rm, fp16_from_ieee(a));
  let flags = ieee_fp16_to_int_exceptions(a, rounded, true, true);
  let candidate = fp16_to_unsigned64(round_toward_zero(), rounded);
  (ieee_probe_flags(flags), candidate)
}

function ieee_u64_to_fp16_probe(rm_bits : bits(3), a : bits(64)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp16_from_unsigned(rm, a);
  let flags = ieee_int64_to_fp16_exceptions(rm, a, true, result);
  (ieee_probe_flags(flags), fp16_to_ieee(result))
}

function ieee_round32_probe(rm_bits : bits(3), a : bits(32), exact_bits : bits(1)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp32_round_to_integral(rm, fp32_from_ieee(a));
  let flags = ieee_round32_exceptions(a, result, exact_bits == 0b1);
  (ieee_probe_flags(flags), fp32_to_ieee(result))
}

function ieee_fp32_to_i32_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let rounded = fp32_round_to_integral(rm, fp32_from_ieee(a));
  let flags = ieee_fp32_to_int_exceptions(a, rounded, false, false);
  let candidate = fp32_to_signed32(round_toward_zero(), rounded);
  (ieee_probe_flags(flags), candidate)
}

function ieee_i32_to_fp32_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp32_from_signed(rm, a);
  let flags = ieee_int32_to_fp32_exceptions(rm, a, false, result);
  (ieee_probe_flags(flags), fp32_to_ieee(result))
}

function ieee_fp32_to_u32_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let rounded = fp32_round_to_integral(rm, fp32_from_ieee(a));
  let flags = ieee_fp32_to_int_exceptions(a, rounded, true, false);
  let candidate = fp32_to_unsigned32(round_toward_zero(), rounded);
  (ieee_probe_flags(flags), candidate)
}

function ieee_u32_to_fp32_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp32_from_unsigned(rm, a);
  let flags = ieee_int32_to_fp32_exceptions(rm, a, true, result);
  (ieee_probe_flags(flags), fp32_to_ieee(result))
}

function ieee_fp32_to_i64_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let rounded = fp32_round_to_integral(rm, fp32_from_ieee(a));
  let flags = ieee_fp32_to_int_exceptions(a, rounded, false, true);
  let candidate = fp32_to_signed64(round_toward_zero(), rounded);
  (ieee_probe_flags(flags), candidate)
}

function ieee_i64_to_fp32_probe(rm_bits : bits(3), a : bits(64)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp32_from_signed(rm, a);
  let flags = ieee_int64_to_fp32_exceptions(rm, a, false, result);
  (ieee_probe_flags(flags), fp32_to_ieee(result))
}

function ieee_fp32_to_u64_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let rounded = fp32_round_to_integral(rm, fp32_from_ieee(a));
  let flags = ieee_fp32_to_int_exceptions(a, rounded, true, true);
  let candidate = fp32_to_unsigned64(round_toward_zero(), rounded);
  (ieee_probe_flags(flags), candidate)
}

function ieee_u64_to_fp32_probe(rm_bits : bits(3), a : bits(64)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp32_from_unsigned(rm, a);
  let flags = ieee_int64_to_fp32_exceptions(rm, a, true, result);
  (ieee_probe_flags(flags), fp32_to_ieee(result))
}

function ieee_round64_probe(rm_bits : bits(3), a : bits(64), exact_bits : bits(1)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp64_round_to_integral(rm, fp64_from_ieee(a));
  let flags = ieee_round64_exceptions(a, result, exact_bits == 0b1);
  (ieee_probe_flags(flags), fp64_to_ieee(result))
}

function ieee_fp64_to_i32_probe(rm_bits : bits(3), a : bits(64)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let rounded = fp64_round_to_integral(rm, fp64_from_ieee(a));
  let flags = ieee_fp64_to_int_exceptions(a, rounded, false, false);
  let candidate = fp64_to_signed32(round_toward_zero(), rounded);
  (ieee_probe_flags(flags), candidate)
}

function ieee_i32_to_fp64_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp64_from_signed(rm, a);
  let flags = ieee_int32_to_fp64_exceptions(rm, a, false, result);
  (ieee_probe_flags(flags), fp64_to_ieee(result))
}

function ieee_fp64_to_u32_probe(rm_bits : bits(3), a : bits(64)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let rounded = fp64_round_to_integral(rm, fp64_from_ieee(a));
  let flags = ieee_fp64_to_int_exceptions(a, rounded, true, false);
  let candidate = fp64_to_unsigned32(round_toward_zero(), rounded);
  (ieee_probe_flags(flags), candidate)
}

function ieee_u32_to_fp64_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp64_from_unsigned(rm, a);
  let flags = ieee_int32_to_fp64_exceptions(rm, a, true, result);
  (ieee_probe_flags(flags), fp64_to_ieee(result))
}

function ieee_fp64_to_i64_probe(rm_bits : bits(3), a : bits(64)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let rounded = fp64_round_to_integral(rm, fp64_from_ieee(a));
  let flags = ieee_fp64_to_int_exceptions(a, rounded, false, true);
  let candidate = fp64_to_signed64(round_toward_zero(), rounded);
  (ieee_probe_flags(flags), candidate)
}

function ieee_i64_to_fp64_probe(rm_bits : bits(3), a : bits(64)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp64_from_signed(rm, a);
  let flags = ieee_int64_to_fp64_exceptions(rm, a, false, result);
  (ieee_probe_flags(flags), fp64_to_ieee(result))
}

function ieee_fp64_to_u64_probe(rm_bits : bits(3), a : bits(64)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let rounded = fp64_round_to_integral(rm, fp64_from_ieee(a));
  let flags = ieee_fp64_to_int_exceptions(a, rounded, true, true);
  let candidate = fp64_to_unsigned64(round_toward_zero(), rounded);
  (ieee_probe_flags(flags), candidate)
}

function ieee_u64_to_fp64_probe(rm_bits : bits(3), a : bits(64)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp64_from_unsigned(rm, a);
  let flags = ieee_int64_to_fp64_exceptions(rm, a, true, result);
  (ieee_probe_flags(flags), fp64_to_ieee(result))
}

function ieee_fp16_to_fp32_probe(rm_bits : bits(3), a : bits(16)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp16_to_fp32(rm, fp16_from_ieee(a));
  let flags = ieee_widen16_to_32_exceptions(a);
  (ieee_probe_flags(flags), fp32_to_ieee(result))
}

function ieee_fp16_to_fp64_probe(rm_bits : bits(3), a : bits(16)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp16_to_fp64(rm, fp16_from_ieee(a));
  let flags = ieee_widen16_to_64_exceptions(a);
  (ieee_probe_flags(flags), fp64_to_ieee(result))
}

function ieee_fp32_to_fp16_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp32_to_fp16(rm, fp32_from_ieee(a));
  let flags = ieee_convert32_to_16_exceptions(rm, a, result);
  (ieee_probe_flags(flags), fp16_to_ieee(result))
}

function ieee_fp32_to_fp64_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(64)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp32_to_fp64(rm, fp32_from_ieee(a));
  let flags = ieee_widen32_to_64_exceptions(a);
  (ieee_probe_flags(flags), fp64_to_ieee(result))
}

function ieee_fp64_to_fp16_probe(rm_bits : bits(3), a : bits(64)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp64_to_fp16(rm, fp64_from_ieee(a));
  let flags = ieee_convert64_to_16_exceptions(rm, a, result);
  (ieee_probe_flags(flags), fp16_to_ieee(result))
}

function ieee_fp64_to_fp32_probe(rm_bits : bits(3), a : bits(64)) -> (bits(5), bits(32)) = {
  let rm = ieee_probe_rm(rm_bits);
  let result = fp64_to_fp32(rm, fp64_from_ieee(a));
  let flags = ieee_convert64_to_32_exceptions(rm, a, result);
  (ieee_probe_flags(flags), fp32_to_ieee(result))
}

function ieee_fp32_to_bf16_probe(rm_bits : bits(3), a : bits(32)) -> (bits(5), bits(16)) = {
  let rm = ieee_probe_rm(rm_bits);
  let bits = fp32_to_bf16(rm, fp32_from_ieee(a));
  let flags = ieee_bf16_from_f32_exceptions(rm, a, bits);
  (ieee_probe_flags(flags), bits)
}

function ieee_rod32_probe(a : bits(32)) -> (bits(5), bits(16)) = {
  let (flags, result) = ieee_rod32_to_16(a);
  (ieee_probe_flags(flags), result)
}

function ieee_rod64_probe(a : bits(64)) -> (bits(5), bits(32)) = {
  let (flags, result) = ieee_rod64_to_32(a);
  (ieee_probe_flags(flags), result)
}

$endif
