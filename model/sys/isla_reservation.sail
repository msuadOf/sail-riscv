// Isla 顺序模型的 LR/SC 状态。并发／其他后端继续选 sys_reservation.sail。
// 不模拟其他 hart 的失效或任意失败；只表达当前单指令前态和显式取消。
register reservation_valid : bool = false
register reservation_addr : physaddrbits = zeros()

// 集合大小为二的幂；默认 1 表示精确地址，平台配置可用 cache block 大小。
let sys_reservation_set_size : range(1, 4096) = config memory.reservation_set_size

val load_reservation : forall 'n, 0 < 'n < max_mem_access . (physaddrbits, int('n)) -> unit
function load_reservation(addr, width) = {
  reservation_addr = addr;
  reservation_valid = true
}

function match_reservation(addr : physaddrbits) -> bool = {
  let size = sys_reservation_set_size;
  let low_mask : physaddrbits = to_bits(size - 1);
  // 外部常量替代仍须满足范围和幂次约束，否则是配置／模型不变量错误。
  assert(size >= 1 & size <= 4096);
  assert(((to_bits(size) : physaddrbits) & low_mask) == zeros());
  let mask = ~(low_mask);
  reservation_valid & ((reservation_addr & mask) == (addr & mask))
}

function cancel_reservation() -> unit = { reservation_valid = false }
function valid_reservation() -> bool = reservation_valid
