// Stage B exercises one complete RISC-V comparison and an isolated numeric
// addition. The demo has no architectural flags and is not a production helper.

val stage_b_cpp_probe : (bits(32), bits(32)) -> (bits(5), bool)

$ifdef SYMBOLIC
function demo_f32_add_bits(a : bits(32), b : bits(32)) -> bits(32) = {
  let x = fp32_from_ieee(a);
  let y = fp32_from_ieee(b);
  let result = fp32_add(riscv_valid_rm_to_ieee(0b000), x, y);
  let raw_result = fp32_to_ieee(result);
  ite(fp32_is_nan(result), 0x7fc00000, raw_result)
}

function stage_b_bf16_interface_bits(a : bits(32)) -> bits(16) =
  fp32_to_bf16(round_nearest_ties_to_even(), fp32_from_ieee(a))

function stage_b_unknown_eq() -> (bits(5), bool) = {
  let a : bits(32) = undefined;
  let b : bits(32) = undefined;
  riscv_f32Eq(a, b)
}

function stage_b_unknown_eq_inputs() -> (bits(32), bits(32), bits(5), bool) = {
  let a : bits(32) = undefined;
  let b : bits(32) = undefined;
  let (flags, equal) = riscv_f32Eq(a, b);
  (a, b, flags, equal)
}

function stage_b_unknown_add_inputs() -> (bits(32), bits(32), bits(32)) = {
  let a : bits(32) = undefined;
  let b : bits(32) = undefined;
  (a, b, demo_f32_add_bits(a, b))
}

function isla_footprint(a : bits(32), b : bits(32)) -> (bits(5), bool, bits(32), bits(16), bits(5), bool, bits(5), bool) = {
  let (flags, equal) = riscv_f32Eq(a, b);
  let (unknown_flags, unknown_equal) = stage_b_unknown_eq();
  let (probe_flags, probe_equal) = stage_b_cpp_probe(a, b);
  (flags, equal, demo_f32_add_bits(a, b), stage_b_bf16_interface_bits(a), unknown_flags, unknown_equal, probe_flags, probe_equal)
}
$endif

function stage_b_cpp_probe(a : bits(32), b : bits(32)) -> (bits(5), bool) =
  riscv_f32Eq(a, b)
