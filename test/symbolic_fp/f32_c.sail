// These probes call the production f32 wrappers. Names match the isolated
// IEEE probe runner, allowing independent SoftFloat expectations.
$ifdef SYMBOLIC
function ieee_add32_probe(rm : bits_rm, a : bits_S, b : bits_S) -> (bits_fflags, bits_S) =
  riscv_f32Add(rm, a, b)

function ieee_sub32_probe(rm : bits_rm, a : bits_S, b : bits_S) -> (bits_fflags, bits_S) =
  riscv_f32Sub(rm, a, b)

function ieee_mul32_probe(rm : bits_rm, a : bits_S, b : bits_S) -> (bits_fflags, bits_S) =
  riscv_f32Mul(rm, a, b)

function ieee_div32_probe(rm : bits_rm, a : bits_S, b : bits_S) -> (bits_fflags, bits_S) =
  riscv_f32Div(rm, a, b)

function ieee_sqrt32_probe(rm : bits_rm, a : bits_S) -> (bits_fflags, bits_S) =
  riscv_f32Sqrt(rm, a)

function ieee_fma32_probe(rm : bits_rm, a : bits_S, b : bits_S, c : bits_S) -> (bits_fflags, bits_S) =
  riscv_f32MulAdd(rm, a, b, c)

function ieee_eq32_probe(a : bits_S, b : bits_S) -> (bits_fflags, bits(1)) = {
  let (flags, result) = riscv_f32Eq(a, b);
  (flags, isla_bool_to_bit(result))
}

function ieee_lt32_probe(a : bits_S, b : bits_S) -> (bits_fflags, bits(1)) = {
  let (flags, result) = riscv_f32Lt(a, b);
  (flags, isla_bool_to_bit(result))
}

function ieee_lt_quiet32_probe(a : bits_S, b : bits_S) -> (bits_fflags, bits(1)) = {
  let (flags, result) = riscv_f32Lt_quiet(a, b);
  (flags, isla_bool_to_bit(result))
}

function ieee_le32_probe(a : bits_S, b : bits_S) -> (bits_fflags, bits(1)) = {
  let (flags, result) = riscv_f32Le(a, b);
  (flags, isla_bool_to_bit(result))
}

function ieee_le_quiet32_probe(a : bits_S, b : bits_S) -> (bits_fflags, bits(1)) = {
  let (flags, result) = riscv_f32Le_quiet(a, b);
  (flags, isla_bool_to_bit(result))
}

// Observe the ordinary candidate used by the ROD wrapper. For rm=6 it must
// use RTZ before the separate odd-bit rule is applied.
function f32_rod_normal_candidate(rm_bits : bits_rm, a : bits_S) -> (bits_fflags, bits_H) = {
  let normal_rm_bits = riscv_f32_to_f16_normal_rm_bits(rm_bits);
  let rm = riscv_valid_rm_to_ieee(normal_rm_bits);
  let result = fp32_to_fp16(rm, fp32_from_ieee(a));
  let exceptions = ieee_convert32_to_16_exceptions(rm, a, result);
  let bits = ite(fp16_is_nan(result), riscv_canonical_nan16(), fp16_to_ieee(result));
  (riscv_pack_ieee_flags(exceptions), bits)
}
$endif
