// 原子 PMA 的级别独立于读写权限；CAS 还按最大宽度限制。
$[test]
function test_atomic_support_levels() -> unit = {
  assert(not(pma_supports_atomic(AMONone, AMOSWAP, 8)));
  assert(pma_supports_atomic(AMOSwap, AMOSWAP, 8));
  assert(not(pma_supports_atomic(AMOSwap, AMOXOR, 8)));
  assert(not(pma_supports_atomic(AMOSwap, AMOADD, 8)));
  assert(pma_supports_atomic(AMOLogical, AMOXOR, 8));
  assert(not(pma_supports_atomic(AMOLogical, AMOMIN, 8)));
  assert(pma_supports_atomic(AMOArithmetic, AMOADD, 8));
  assert(not(pma_supports_atomic(AMOArithmetic, AMOCAS, 4)));
  assert(pma_supports_atomic(AMOCASW, AMOCAS, 4));
  assert(not(pma_supports_atomic(AMOCASW, AMOCAS, 8)));
  assert(pma_supports_atomic(AMOCASD, AMOCAS, 8));
  assert(not(pma_supports_atomic(AMOCASD, AMOCAS, 16)));
  assert(pma_supports_atomic(AMOCASQ, AMOCAS, 16));
  assert(pma_supports_atomic(AMOCASW, AMOADD, 8));
}

// 小规模权限回归在 M/Bare、PMP count=0 下运行，不需要真实设备。
function configure_atomic_test(support : AtomicSupport, reserve : Reservability) -> unit = {
  cur_privilege = Machine;
  mstatus = Mk_Mstatus(zeros());
  pma_regions = [|struct {
    base = 0x0000000080000000,
    size = 0x0000000000001000,
    attributes = struct {
      cacheable = true, coherent = true, executable = true,
      readable = true, writable = true,
      read_idempotent = true, write_idempotent = true,
      misaligned_fault = NoFault, atomic_support = support,
      reservability = reserve, supports_cbo_zero = true
    },
    include_in_device_tree = false
  }|]
}

$[test]
function test_atomic_permissions() -> unit = {
  configure_atomic_test(AMOSwap, RsrvNone);
  let addr = Physaddr(to_bits(2147483648));
  assert(phys_access_check(Atomic(AMOSWAP, Data, Data), Machine, addr, 8, true) == None());
  assert(phys_access_check(Atomic(AMOADD, Data, Data), Machine, addr, 8, true) == Some(E_SAMO_Access_Fault()));
  assert(phys_access_check(LoadReserved(Data), Machine, addr, 8, true) == Some(E_Load_Access_Fault()));
  assert(phys_access_check(StoreConditional(Data), Machine, addr, 8, true) == Some(E_SAMO_Access_Fault()));
  configure_atomic_test(AMONone, RsrvNone);
  assert(phys_access_check(Atomic(AMOSWAP, Data, Data), Machine, addr, 8, true) == Some(E_SAMO_Access_Fault()));
  configure_atomic_test(AMOArithmetic, RsrvEventual);
  assert(phys_access_check(Atomic(AMOADD, Data, Data), Machine, addr, 8, true) == None());
  assert(phys_access_check(LoadReserved(Data), Machine, addr, 8, true) == None());
  assert(phys_access_check(StoreConditional(Data), Machine, addr, 8, true) == None());
}

$[test]
function test_atomic_sc_denied() -> unit = {
  configure_atomic_test(AMOArithmetic, RsrvNone);
  let addr = Virtaddr(to_bits(2147483648));
  assert(vmem_write_addr(addr, 8, 0x0000000000000001, StoreConditional(Data), false, false, true)
         == Err(Memory_Exception(addr, E_SAMO_Access_Fault())));
}

$[test]
function test_atomic_sc_misaligned() -> unit = {
  configure_atomic_test(AMOArithmetic, RsrvEventual);
  let addr = Virtaddr(to_bits(2147483649));
  assert(vmem_write_addr(addr, 8, 0x0000000000000001, StoreConditional(Data), false, false, true)
         == Err(Memory_Exception(addr, E_SAMO_Addr_Align())));
}

$[test]
function test_atomic_cas_denied() -> unit = {
  configure_atomic_test(AMOArithmetic, RsrvEventual);
  X(Regidx(to_bits(1))) = to_bits(2147483648);
  X(Regidx(to_bits(2))) = to_bits(1);
  X(Regidx(to_bits(4))) = to_bits(2);
  // 无论旧内存值是否等于比较值，都必须在读取前按 CAS 权限拒绝。
  assert(execute_amo_width(AMOCAS, false, false, Regidx(to_bits(2)), Regidx(to_bits(1)), 8, Regidx(to_bits(4)))
         == Memory_Exception(Virtaddr(to_bits(2147483648)), E_SAMO_Access_Fault()));
}
