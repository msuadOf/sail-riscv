// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

$ifdef SYMBOLIC
register __isla_use_extra_ops : bool = false

// 通用商环乘法：模数为X^W+r，r须为调用处的常量；当前Isla支持1..128位。
val gf2_poly_mul_mod = pure "gf2_poly_mul_mod" : forall 'n, 1 <= 'n <= 128. (bits('n), bits('n), bits('n)) -> bits('n)
$else
val gf2_poly_mul_mod : forall 'n, 1 <= 'n <= 128. (bits('n), bits('n), bits('n)) -> bits('n)
function gf2_poly_mul_mod(a, b, r) = {
  var Z : bits('n) = zeros();
  var H : bits('n) = b;
  foreach (i from 0 to ('n - 1)) {
    if a[i] == 0b1 then Z = Z ^ H;
    let reduce = H['n - 1] == 0b1;
    H = H << 1;
    if reduce then H = H ^ r;
  };
  Z
}
$endif

// Reverse bits in each byte
$ifdef SYMBOLIC
val brev8 = pure "isla_brev8" : forall 'm, 'm >= 0 & mod('m, 8) == 0. (bits('m)) -> bits('m)
$else
val brev8 : forall 'm, 'm >= 0 & mod('m, 8) == 0. (bits('m)) -> bits('m)
function brev8(input) = {
  var output : bits('m) = zeros();
  foreach (i from 0 to ('m - 8) by 8)
    output[i+7..i] = reverse_bits(input[i+7..i]);
  output
}
$endif

// Carry-less multiply.
$ifndef SYMBOLIC
val carryless_mul : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits(2 * 'n)
function carryless_mul(a, b) = {
  var result : bits(2 * 'n) = zeros();
  foreach (i from 0 to ('n - 1)) {
    if   a[i] == 0b1
    then result = result ^ (zero_extend(b) << i);
  };
  result
}
$else
val carryless_mul = pure "isla_carryless_mul" : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits(2 * 'n)
$endif

// Reverse carry-less multiply.
$ifndef SYMBOLIC
val carryless_mulr : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
function carryless_mulr(a, b) = {
  var result : bits('n) = zeros();
  foreach (i from 0 to ('n - 1)) {
    if   a[i] == 0b1
    then result = result ^ (b >> ('n - i - 1));
  };
  result
}
$else
val carryless_mulr = pure "isla_carryless_mulr" : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
$endif

// Equivalent reverse carry-less multiply.
private val carryless_mul_reversed : forall 'n, 'n > 0. (bits('n), bits('n)) -> bits('n)
function carryless_mul_reversed(a, b) = {
  let prod = carryless_mul(reverse_bits(a), reverse_bits(b));
  reverse_bits(prod['n - 1 .. 0])
}

val mult_to_bits_half : forall 'l, 'l > 0 . (implicit('l), Signedness, Signedness, bits('l), bits('l), VectorHalf) -> bits('l)
function mult_to_bits_half(l, sign1, sign2, rs1_bits, rs2_bits, result_part) = {
  let rs1_int : int = match sign1 {
    Signed   => signed(rs1_bits),
    Unsigned => unsigned(rs1_bits),
  };
  let rs2_int : int = match sign2 {
    Signed   => signed(rs2_bits),
    Unsigned => unsigned(rs2_bits),
  };

  let result_wide = to_bits_truncate(2 * l, rs1_int * rs2_int);
  match result_part {
    High => result_wide[(2 * l - 1) .. l],
    Low  => result_wide[(l - 1) .. 0],
  }
}

$[property]
function cmulr_equivalence(a : bits(16), b : bits(16)) -> bool = {
  carryless_mul_reversed(a, b) == carryless_mulr(a, b)
}

$ifdef SYMBOLIC
val rev8 = pure "isla_rev8" : forall 'm, 'm >= 0 & mod('m, 8) == 0. (bits('m)) -> bits('m)
$else
val rev8 : forall 'm, 'm >= 0 & mod('m, 8) == 0. (bits('m)) -> bits('m)
function rev8(input) = {
  var output : bits('m) = zeros();
  foreach (i from 0 to ('m - 8) by 8) {
    output[(i + 7)..i] = input[('m - i - 1) .. ('m - i - 8)];
  };
  output
}
$endif

$ifndef SYMBOLIC
val count_ones : forall 'n, 'n >= 0. (bits('n)) -> range(0, 'n)
function count_ones(x) = {
  var count : range(0, 'n) = 0;
  foreach (i from 0 to ('n - 1)) {
    if x[i] == 0b1 then {
      let new_count = count + 1;
      assert(new_count <= 'n);
      count = new_count;
    }
  };
  count
}
$else
val count_ones = pure "isla_count_ones" : forall 'n, 'n >= 0. (bits('n)) -> range(0, 'n)
$endif

$ifdef SYMBOLIC
// 全域有限表：K位索引选择2^K个同宽表项，下标0对应索引0。
val lookup_bits = pure "lookup_bits" :
  forall 'k 'w, 'k > 0 & 'w > 0. (bits('k), vector(2 ^ 'k, bits('w))) -> bits('w)

// Exclusive前缀：第i项计数输入中下标小于i的置位，按输出位宽截断。
val prefix_popcount = pure "prefix_popcount" :
  forall 'n 'm, 'n >= 0 & 'm > 0. (bits('n), int('m)) -> vector('n, bits('m))
$else
val prefix_popcount :
  forall 'n 'm, 'n >= 0 & 'm > 0. (bits('n), int('m)) -> vector('n, bits('m))
function prefix_popcount(input, width) = {
  var result : vector('n, bits('m)) = vector_init(zeros());
  var sum : int = 0;
  foreach (i from 0 to ('n - 1)) {
    result[i] = to_bits_unsafe(width, sum);
    if input[i] == 0b1 then sum = sum + 1
  };
  result
}
$endif


// 保序打包：q选中的src元素从下标0连续写入，剩余位置保留old。
$ifdef SYMBOLIC
val stable_pack = pure "stable_pack" :
  forall 'n 'w, 'n >= 0 & 'w > 0. (bits('n), vector('n, bits('w)), vector('n, bits('w))) -> vector('n, bits('w))
$else
val stable_pack :
  forall 'n 'w, 'n >= 0 & 'w > 0. (bits('n), vector('n, bits('w)), vector('n, bits('w))) -> vector('n, bits('w))
function stable_pack(q, src, old) = {
  var result : vector('n, bits('w)) = old;
  var count : nat = 0;
  foreach (i from 0 to ('n - 1)) {
    if q[i] == 0b1 then {
      let 'p = count;
      assert('p < 'n);
      result['p] = src[i];
      count = count + 1;
    }
  };
  if count < 'n then {
    let 'p = count;
    foreach (i from 'p to ('n - 1)) { result[i] = old[i] }
  };
  result
}
$endif
