// 普通非对齐访问的区域策略与 PBMT 覆盖；保存并恢复全局 PMA。
$[test]
function test_misaligned_access_policy() -> unit = {
  let saved_pmas = pma_regions;
  let attr : PMA = struct {
    cacheable = true, coherent = true, executable = true,
    readable = true, writable = true, read_idempotent = true, write_idempotent = true,
    misaligned_fault = NoFault, reservability = RsrvEventual, supports_cbo_zero = true
  };
  let region : PMA_Region = struct {
    base = 0x0000000080000000, size = 0x0000000000001000,
    attributes = attr, include_in_device_tree = false
  };
  pma_regions = [|region|];
  let addr = Physaddr(zero_extend(0x80000001));
  assert(misaligned_pma_check(addr, Load(Data), 0b00) == None());
  assert(misaligned_pma_check(addr, Store(Data), 0b00) == None());
  assert(misaligned_pma_check(addr, Load(Data), 0b01) == Some(E_Load_Addr_Align()));
  assert(misaligned_pma_check(addr, Store(Data), 0b01) == Some(E_SAMO_Addr_Align()));
  assert(misaligned_pma_check(addr, Load(Data), 0b10) == Some(E_Load_Access_Fault()));
  assert(misaligned_pma_check(addr, Store(Data), 0b10) == Some(E_SAMO_Access_Fault()));
  pma_regions = [|{region with attributes = {attr with misaligned_fault = AccessFault}}|];
  assert(misaligned_pma_check(addr, Load(Data), 0b00) == Some(E_Load_Access_Fault()));
  assert(misaligned_pma_check(addr, Store(Data), 0b00) == Some(E_SAMO_Access_Fault()));
  // NC 覆盖静态非对齐策略；底层读写权限仍在物理访问时检查。
  assert(misaligned_pma_check(addr, Load(Data), 0b01) == Some(E_Load_Addr_Align()));
  pma_regions = [|{region with attributes = {attr with misaligned_fault = AlignmentFault}}|];
  assert(misaligned_pma_check(addr, Store(Data), 0b00) == Some(E_SAMO_Addr_Align()));
  pma_regions = saved_pmas;
}
