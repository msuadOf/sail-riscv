// 使用共享 Sail 类型及 RISC-V 位序转换的隔离探针。
$ifdef SYMBOLIC
function type_reuse_flags(nv : bool, dz : bool, oflow : bool, uflow : bool, nx : bool) -> bits(10) = {
  let facts = ieee_exception_facts(nv, dz, oflow, uflow, nx);
  ieee_pack_shared_flags(facts) @ riscv_pack_ieee_flags(facts)
}

function type_reuse_classify16(raw : bits(16)) -> bits(5) =
  isla_bool_to_bit(ieee_is_nan(raw)) @ isla_bool_to_bit(ieee_is_snan(raw)) @
  isla_bool_to_bit(ieee_is_inf(raw)) @ isla_bool_to_bit(ieee_is_zero(raw)) @
  isla_bool_to_bit(ieee_is_finite(raw))

function type_reuse_classify32(raw : bits(32)) -> bits(5) =
  isla_bool_to_bit(ieee_is_nan(raw)) @ isla_bool_to_bit(ieee_is_snan(raw)) @
  isla_bool_to_bit(ieee_is_inf(raw)) @ isla_bool_to_bit(ieee_is_zero(raw)) @
  isla_bool_to_bit(ieee_is_finite(raw))

function type_reuse_classify64(raw : bits(64)) -> bits(5) =
  isla_bool_to_bit(ieee_is_nan(raw)) @ isla_bool_to_bit(ieee_is_snan(raw)) @
  isla_bool_to_bit(ieee_is_inf(raw)) @ isla_bool_to_bit(ieee_is_zero(raw)) @
  isla_bool_to_bit(ieee_is_finite(raw))

function type_reuse_unknown16() -> bits(5) = {
  let raw : bits(16) = undefined;
  type_reuse_classify16(raw)
}

function type_reuse_unknown32() -> bits(5) = {
  let raw : bits(32) = undefined;
  type_reuse_classify32(raw)
}

function type_reuse_unknown64() -> bits(5) = {
  let raw : bits(64) = undefined;
  type_reuse_classify64(raw)
}
$endif
