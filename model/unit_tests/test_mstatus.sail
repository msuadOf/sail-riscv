// Verify that the reset sxl and uxl are correct.
$[test]
function test_mstatus_sxl_uxl_reset_values() -> unit = {
  let mstatush_val : bits(32) = match xlen {
    32 => read_CSR(0x310),
    64 => read_CSR(0x300)[63 .. 32],
    _  => internal_error(__FILE__, __LINE__, "unsupported xlen"),
  };
  // 0 = 32, 1 = 64, 2 = 128, but on RV32 SXL/UXL don't actually
  // exist (they are currently WPRI). For now we set them to 0.
  // If those bits are used in future we may expect a different value.
  let expected_xl : bits(2) = match xlen {
    32 => 0b00,
    64 => 0b10,
    _  => internal_error(__FILE__, __LINE__, "unsupported xlen"),
  };
  // SXL
  assert(mstatush_val[3 .. 2] == expected_xl);
  // UXL
  assert(mstatush_val[1 .. 0] == expected_xl);
}

// 无 S 时 SPELP 必须只读零；MPELP 仍仅取决于 Zicfilp。
$[test]
function test_mstatus_pelp_warl() -> unit = {
  let saved = mstatus;
  let requested = [saved with SPELP = 0b1, MPELP = 0b1];
  let _ = write_CSR(0x300, requested.bits[xlen - 1 .. 0]);
  assert(mstatus[SPELP] == bool_to_bit(hartSupports(Ext_Zicfilp) & hartSupports(Ext_S)));
  if xlen == 64 then assert(mstatus[MPELP] == bool_to_bit(hartSupports(Ext_Zicfilp)));
  mstatus = saved;
}

// 保留有 S 无 F 的浮点模拟选择，并检查 Zfinx 与无 F/无 S 的只读零。
$[test]
function test_mstatus_fs_warl() -> unit = {
  let saved = mstatus;
  let writable = not(hartSupports(Ext_Zfinx)) & (hartSupports(Ext_F) | hartSupports(Ext_S));
  foreach (i from 0 to 3) {
    let fs : bits(2) = to_bits(2, i);
    let requested = [saved with FS = fs];
    let _ = write_CSR(0x300, requested.bits[xlen - 1 .. 0]);
    assert(mstatus[FS] == (if writable then fs else 0b00));
  };
  mstatus = saved;
}
