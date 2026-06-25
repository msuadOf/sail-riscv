// Pure unit tests for small prelude bitvector helpers.

$[test]
function test_get_field_extracts_unshifted_value() -> unit = {
  let reg  : bits(32) = 0xDEADBEEF;
  let mask : bits(32) = 0x0000FF00;

  assert(get_field(reg, mask) == 0x000000BE);
}

$[test]
function test_set_field_replaces_masked_bits_and_preserves_others() -> unit = {
  let reg   : bits(32) = 0x12345678;
  let mask  : bits(32) = 0x00FF0000;
  let value : bits(32) = 0x000000AB;
  let updated = set_field(reg, mask, value);

  assert(updated == 0x12AB5678);
  assert(get_field(updated, mask) == value);
}

$[test]
function test_set_field_truncates_value_to_mask_width() -> unit = {
  let reg   : bits(32) = 0x12345678;
  let mask  : bits(32) = 0x00000F00;
  let value : bits(32) = 0x000000FF;

  assert(set_field(reg, mask, value) == 0x12345F78);
}

$[test]
function test_mux2_selects_between_whole_bitvectors() -> unit = {
  let input0 : bits(32) = 0xAAAAAAAA;
  let input1 : bits(32) = 0x55555555;

  assert(mux2(0b0, input0, input1) == input0);
  assert(mux2(0b1, input0, input1) == input1);
}
