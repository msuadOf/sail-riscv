// 仅屏蔽手册要求只读零的委托位，保留其它既有可写位。
$[test]
function test_medeleg_read_only_zero() -> unit = {
  let saved = medeleg;
  let _ = write_CSR(0x302, ones());
  let actual = read_CSR(0x302);
  assert(actual[11] == 0b0 & actual[16] == 0b0);
  assert(actual[13] == 0b1 & actual[2] == 0b1);
  medeleg = saved;
}

// RV64 的保留 MODE 写入必须保持整个旧 SATP，而非只保持 MODE。
$[test]
function test_satp_reserved_mode_write_ignored() -> unit = {
  if xlen == 64 & hartSupports(Ext_S) then {
    let saved = satp;
    let saved_misa = misa;
    // 单测初始化只设置 MXL；显式启用已有的 S/U，才能写入支持的翻译模式。
    misa = [misa with S = 0b1, U = 0b1];
    let previous : bits(64) = if hartSupports(Ext_Sv39) then 0x8000100000000001 else zeros();
    let _ = write_CSR(0x180, previous);
    assert(read_CSR(0x180) == previous);
    foreach (i from 1 to 15) {
      if i < 8 | i > 10 then {
        let requested = [Mk_Satp64(0x0000200000000002) with Mode = to_bits(4, i)];
        let _ = write_CSR(0x180, requested.bits);
        assert(read_CSR(0x180) == previous);
      }
    };
    satp = saved;
    misa = saved_misa;
  }
}
