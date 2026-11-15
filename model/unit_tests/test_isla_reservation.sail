// 同一组用例分别以精确地址和 64 字节集合配置运行。
$[test]
function test_isla_reservation_transitions() -> unit = {
  cancel_reservation();
  assert(not(valid_reservation()));
  load_reservation(to_bits(4096), 8);
  assert(reservation_valid);
  assert(reservation_addr == to_bits(4096));
  assert(valid_reservation());
  assert(match_reservation(to_bits(4096)));
  assert(match_reservation(to_bits(4104)) == (sys_reservation_set_size > 8));
  assert(not(match_reservation(to_bits(8192))));
  cancel_reservation();
  assert(not(valid_reservation()));
  assert(not(match_reservation(to_bits(4096))));
}
