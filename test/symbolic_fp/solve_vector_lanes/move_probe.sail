val lane_select = pure "isla_vector_select" : forall 'n 'm, 'n >= 0 . (bits('n), vector('n, bits('m)), vector('n, bits('m))) -> vector('n, bits('m))
val body_mask = pure "isla_init_mask" : forall 'n 'p, 'n >= 0 . (int('n), nat, int, int('p), bits('n)) -> bits('n)

function move_old(mask : bits(8), scalar : bits(16), old : vector(8, bits(16))) -> vector(8, bits(16)) = {
  var result = old;
  foreach (i from 0 to 7) {
    if mask[i] == 0b1 then result[i] = scalar
  };
  result
}

function move_new(mask : bits(8), scalar : bits(16), old : vector(8, bits(16))) -> vector(8, bits(16)) =
  lane_select(mask, old, vector_init(scalar))

function merge_old(vm : bits(8), scalar : bits(16), src : vector(8, bits(16)), old : vector(8, bits(16)), start : nat, last : int, real : int) -> vector(8, bits(16)) = {
  var result : vector(8, bits(16)) = vector_init(zeros());
  foreach (i from 0 to 7) {
    if i < start then result[i] = old[i]
    else if i > last | i >= real then result[i] = old[i]
    else result[i] = if vm[i] == 0b1 then scalar else src[i]
  };
  result
}

function merge_new(vm : bits(8), scalar : bits(16), src : vector(8, bits(16)), old : vector(8, bits(16)), start : nat, last : int, real : int) -> vector(8, bits(16)) = {
  let active = body_mask(8, start, last, real, ones());
  let candidate = lane_select(vm, src, vector_init(scalar));
  lane_select(active, old, candidate)
}

function probe_old_move() -> vector(8, bits(16)) = {
  let mask : bits(8) = undefined;
  let scalar : bits(16) = undefined;
  let old : vector(8, bits(16)) = undefined;
  move_old(mask, scalar, old)
}

function probe_new_move() -> vector(8, bits(16)) = {
  let mask : bits(8) = undefined;
  let scalar : bits(16) = undefined;
  let old : vector(8, bits(16)) = undefined;
  move_new(mask, scalar, old)
}

function eq_move() -> bool = {
  let mask : bits(8) = undefined;
  let scalar : bits(16) = undefined;
  let old : vector(8, bits(16)) = undefined;
  let a = move_old(mask, scalar, old);
  let b = move_new(mask, scalar, old);
  var same : bool = true;
  foreach (i from 0 to 7) { same = strict_and_bool(same, a[i] == b[i]) };
  same
}

function probe_old_merge() -> vector(8, bits(16)) = {
  let vm : bits(8) = undefined;
  let scalar : bits(16) = undefined;
  let src : vector(8, bits(16)) = undefined;
  let old : vector(8, bits(16)) = undefined;
  merge_old(vm, scalar, src, old, 1, 5, 4)
}

function probe_new_merge() -> vector(8, bits(16)) = {
  let vm : bits(8) = undefined;
  let scalar : bits(16) = undefined;
  let src : vector(8, bits(16)) = undefined;
  let old : vector(8, bits(16)) = undefined;
  merge_new(vm, scalar, src, old, 1, 5, 4)
}

function eq_merge() -> bool = {
  let vm : bits(8) = undefined;
  let scalar : bits(16) = undefined;
  let src : vector(8, bits(16)) = undefined;
  let old : vector(8, bits(16)) = undefined;
  let a = merge_old(vm, scalar, src, old, 1, 5, 4);
  let b = merge_new(vm, scalar, src, old, 1, 5, 4);
  var same : bool = true;
  foreach (i from 0 to 7) { same = strict_and_bool(same, a[i] == b[i]) };
  same
}

function eq_merge_shape(start : nat, last : int, real : int) -> bool = {
  let vm : bits(8) = undefined;
  let scalar : bits(16) = undefined;
  let src : vector(8, bits(16)) = undefined;
  let old : vector(8, bits(16)) = undefined;
  let a = merge_old(vm, scalar, src, old, start, last, real);
  let b = merge_new(vm, scalar, src, old, start, last, real);
  var same : bool = true;
  foreach (i from 0 to 7) { same = strict_and_bool(same, a[i] == b[i]) };
  same
}

function eq_merge_vl0() -> bool = eq_merge_shape(0, -1, 4)
function eq_merge_prestart() -> bool = eq_merge_shape(5, 7, 8)
function eq_merge_fractional() -> bool = eq_merge_shape(0, 7, 2)
function eq_merge_full() -> bool = eq_merge_shape(0, 7, 8)

function new_merge_shape(start : nat, last : int, real : int) -> vector(8, bits(16)) = {
  let vm : bits(8) = undefined;
  let scalar : bits(16) = undefined;
  let src : vector(8, bits(16)) = undefined;
  let old : vector(8, bits(16)) = undefined;
  merge_new(vm, scalar, src, old, start, last, real)
}
function new_merge_vl0() -> vector(8, bits(16)) = new_merge_shape(0, -1, 4)
function new_merge_prestart() -> vector(8, bits(16)) = new_merge_shape(5, 7, 8)
function new_merge_fractional() -> vector(8, bits(16)) = new_merge_shape(0, 7, 2)
function new_merge_full() -> vector(8, bits(16)) = new_merge_shape(0, 7, 8)
