// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

function clause currentlyEnabled(Ext_Zvl32b) = hartSupports(Ext_Zvl32b)
function clause currentlyEnabled(Ext_Zvl64b) = hartSupports(Ext_Zvl64b)
function clause currentlyEnabled(Ext_Zvl128b) = hartSupports(Ext_Zvl128b)
function clause currentlyEnabled(Ext_Zvl256b) = hartSupports(Ext_Zvl256b)
function clause currentlyEnabled(Ext_Zvl512b) = hartSupports(Ext_Zvl512b)
function clause currentlyEnabled(Ext_Zvl1024b) = hartSupports(Ext_Zvl1024b)

// TODO: the interaction of Ext_Zve32x with a writable misa.V when misa.V == 0 needs settling.
function clause currentlyEnabled(Ext_Zve32x) = hartSupports(Ext_Zve32x) & currentlyEnabled(Ext_Zvl32b) & (mstatus[VS] != 0b00) & currentlyEnabled(Ext_Zicsr)
function clause currentlyEnabled(Ext_Zve32f) = hartSupports(Ext_Zve32f) & currentlyEnabled(Ext_Zve32x) & currentlyEnabled(Ext_F)
function clause currentlyEnabled(Ext_Zve64x) = hartSupports(Ext_Zve64x) & currentlyEnabled(Ext_Zvl64b) & currentlyEnabled(Ext_Zve32x)
function clause currentlyEnabled(Ext_Zve64f) = hartSupports(Ext_Zve64f) & currentlyEnabled(Ext_Zve64x) & currentlyEnabled(Ext_Zve32f)
function clause currentlyEnabled(Ext_Zve64d) = hartSupports(Ext_Zve64d) & currentlyEnabled(Ext_Zve64f) & currentlyEnabled(Ext_D)

function clause currentlyEnabled(Ext_V) = hartSupports(Ext_V) & (misa[V] == 0b1) & currentlyEnabled(Ext_Zvl128b) & currentlyEnabled(Ext_Zve64d)

function clause currentlyEnabled(Ext_Zvfh)    = hartSupports(Ext_Zvfh)     & currentlyEnabled(Ext_Zve32f) & currentlyEnabled(Ext_Zfhmin)
function clause currentlyEnabled(Ext_Zvfhmin) = (hartSupports(Ext_Zvfhmin) & currentlyEnabled(Ext_Zve32f)) | currentlyEnabled(Ext_Zvfh)

function assert_sew(SEW : int) -> unit = {
  match SEW {
    8  => (),
    16 => (),
    32 => (),
    64 => (),
    _  => assert(false)
  }
}

val checked_sew_value : int -> sew_bitsize
function checked_sew_value(SEW) = {
  match SEW {
    8  => 8,
    16 => 16,
    32 => 32,
    64 => 64,
    _  => {
      assert(false);
      8
    }
  }
}

function assert_lmul_pow(LMUL_pow : int) -> unit = {
  match LMUL_pow {
    -3 => (),
    -2 => (),
    -1 => (),
    0  => (),
    1  => (),
    2  => (),
    3  => (),
    _  => assert(false)
  }
}

val checked_lmul_group_size : int -> {1, 2, 4, 8}
function checked_lmul_group_size(LMUL_pow) = {
  match LMUL_pow {
    -3 => 1,
    -2 => 1,
    -1 => 1,
    0  => 1,
    1  => 2,
    2  => 4,
    3  => 8,
    _  => {
      assert(false);
      1
    }
  }
}

val checked_lmul_real_num_elem : forall 'n, 'n >= 0. (int('n), int) -> int
function checked_lmul_real_num_elem(num_elem, LMUL_pow) = {
  match LMUL_pow {
    -3 => num_elem / 8,
    -2 => num_elem / 4,
    -1 => num_elem / 2,
    0  => num_elem,
    1  => num_elem,
    2  => num_elem,
    3  => num_elem,
    _  => {
      assert(false);
      num_elem
    }
  }
}

val checked_sew_start_bound : int -> int
function checked_sew_start_bound(SEW_pow) = {
  match SEW_pow {
    3 => vlen - 1,
    4 => vlen / 2 - 1,
    5 => vlen / 4 - 1,
    6 => vlen / 8 - 1,
    _ => {
      assert(false);
      0
    }
  }
}

function assert_widened_sew(SEW : int) -> unit = {
  match SEW {
    16 => (),
    32 => (),
    64 => (),
    _  => assert(false)
  }
}

function assert_narrowing_sew(SEW : int) -> unit = {
  match SEW {
    8  => (),
    16 => (),
    32 => (),
    _  => assert(false)
  }
}

function assert_sew_32(SEW : int) -> unit = {
  match SEW {
    32 => (),
    _  => assert(false)
  }
}

function assert_sew_32_or_64(SEW : int) -> unit = {
  match SEW {
    32 => (),
    64 => (),
    _  => assert(false)
  }
}

function assert_widened_lmul_pow(LMUL_pow : int) -> unit = {
  match LMUL_pow {
    -2 => (),
    -1 => (),
    0  => (),
    1  => (),
    2  => (),
    3  => (),
    _  => assert(false)
  }
}

function assert_nfields(nf : int) -> unit = {
  match nf {
    1 => (),
    2 => (),
    3 => (),
    4 => (),
    5 => (),
    6 => (),
    7 => (),
    8 => (),
    _ => assert(false)
  }
}

function assert_vector_num_elem_upto_32(num_elem : int) -> unit = {
  if num_elem <= 8 then {
    match num_elem {
      1 => (),
      2 => (),
      4 => (),
      8 => (),
      _ => assert(false)
    }
  } else {
    match num_elem {
      16 => (),
      32 => (),
      _  => assert(false)
    }
  }
}

function assert_vector_num_elem_upto_64(num_elem : int) -> unit = {
  if num_elem <= 16 then {
    match num_elem {
      1  => (),
      2  => (),
      4  => (),
      8  => (),
      16 => (),
      _  => assert(false)
    }
  } else {
    match num_elem {
      32 => (),
      64 => (),
      _  => assert(false)
    }
  }
}

function assert_vector_num_elem_upto_128(num_elem : int) -> unit = {
  if num_elem <= 16 then {
    match num_elem {
      1  => (),
      2  => (),
      4  => (),
      8  => (),
      16 => (),
      _  => assert(false)
    }
  } else if num_elem <= 64 then {
    match num_elem {
      32 => (),
      64 => (),
      _  => assert(false)
    }
  } else {
    match num_elem {
      128 => (),
      _   => assert(false)
    }
  }
}

function assert_vector_num_elem_upto_256(num_elem : int) -> unit = {
  if num_elem <= 16 then {
    match num_elem {
      1  => (),
      2  => (),
      4  => (),
      8  => (),
      16 => (),
      _  => assert(false)
    }
  } else if num_elem <= 64 then {
    match num_elem {
      32 => (),
      64 => (),
      _  => assert(false)
    }
  } else {
    match num_elem {
      128 => (),
      256 => (),
      _   => assert(false)
    }
  }
}

function assert_vector_num_elem_upto_512(num_elem : int) -> unit = {
  if num_elem <= 16 then {
    match num_elem {
      1  => (),
      2  => (),
      4  => (),
      8  => (),
      16 => (),
      _  => assert(false)
    }
  } else if num_elem <= 64 then {
    match num_elem {
      32 => (),
      64 => (),
      _  => assert(false)
    }
  } else if num_elem <= 256 then {
    match num_elem {
      128 => (),
      256 => (),
      _   => assert(false)
    }
  } else {
    match num_elem {
      512 => (),
      _   => assert(false)
    }
  }
}

function assert_vector_num_elem_upto_1024(num_elem : int) -> unit = {
  if num_elem <= 16 then {
    match num_elem {
      1  => (),
      2  => (),
      4  => (),
      8  => (),
      16 => (),
      _  => assert(false)
    }
  } else if num_elem <= 64 then {
    match num_elem {
      32 => (),
      64 => (),
      _  => assert(false)
    }
  } else if num_elem <= 256 then {
    match num_elem {
      128 => (),
      256 => (),
      _   => assert(false)
    }
  } else {
    match num_elem {
      512  => (),
      1024 => (),
      _    => assert(false)
    }
  }
}

function assert_vector_num_elem(num_elem : int) -> unit = {
  assert(num_elem <= vlen);
  if vlen <= 32 then assert_vector_num_elem_upto_32(num_elem)
  else if vlen <= 64 then assert_vector_num_elem_upto_64(num_elem)
  else if vlen <= 128 then assert_vector_num_elem_upto_128(num_elem)
  else if vlen <= 256 then assert_vector_num_elem_upto_256(num_elem)
  else if vlen <= 512 then assert_vector_num_elem_upto_512(num_elem)
  else assert_vector_num_elem_upto_1024(num_elem)
}

val checked_vector_num_elem_value : forall 'n, 'n >= 0. int('n) -> int('n)
function checked_vector_num_elem_value(num_elem) = {
  assert(num_elem <= vlen);
  if vlen <= 32 then {
    match num_elem {
      1  => 1,
      2  => 2,
      4  => 4,
      8  => 8,
      16 => 16,
      32 => 32,
      _  => {
        assert(false);
        1
      }
    }
  } else if vlen <= 64 then {
    match num_elem {
      1  => 1,
      2  => 2,
      4  => 4,
      8  => 8,
      16 => 16,
      32 => 32,
      64 => 64,
      _  => {
        assert(false);
        1
      }
    }
  } else if vlen <= 128 then {
    match num_elem {
      1   => 1,
      2   => 2,
      4   => 4,
      8   => 8,
      16  => 16,
      32  => 32,
      64  => 64,
      128 => 128,
      _   => {
        assert(false);
        1
      }
    }
  } else if vlen <= 256 then {
    match num_elem {
      1   => 1,
      2   => 2,
      4   => 4,
      8   => 8,
      16  => 16,
      32  => 32,
      64  => 64,
      128 => 128,
      256 => 256,
      _   => {
        assert(false);
        1
      }
    }
  } else if vlen <= 512 then {
    match num_elem {
      1   => 1,
      2   => 2,
      4   => 4,
      8   => 8,
      16  => 16,
      32  => 32,
      64  => 64,
      128 => 128,
      256 => 256,
      512 => 512,
      _   => {
        assert(false);
        1
      }
    }
  } else {
    match num_elem {
      1    => 1,
      2    => 2,
      4    => 4,
      8    => 8,
      16   => 16,
      32   => 32,
      64   => 64,
      128  => 128,
      256  => 256,
      512  => 512,
      1024 => 1024,
      _    => {
        assert(false);
        1
      }
    }
  }
}

// Get the total number of elements in a register group (not considering `vl`).
// For fractional groups (negative LMUL_pow) we return the number of elements
// in a single register. The fractional aspect is handled by `init_masked_result()`.
//
// The minimum number of elements is 1.
// The maximum is VLMAX = LMUL*VLEN/SEW. VLMAX can never be more than vlen
// because the minimum SEW is 8 and the maximum LMUL is 8. This is also
// true because all elements must be able to fit into a single register
// at 1-bit per element for masks.
function get_num_elem(LMUL_pow : LMUL_pow, SEW : sew_bitsize) -> range(1, vlen) = {
  assert(vlen >= SEW);
  match SEW {
    8 => match LMUL_pow {
      -3 => vlen / 8,
      -2 => vlen / 8,
      -1 => vlen / 8,
      0  => vlen / 8,
      1  => vlen / 4,
      2  => vlen / 2,
      3  => vlen,
    },
    16 => match LMUL_pow {
      -3 => vlen / 16,
      -2 => vlen / 16,
      -1 => vlen / 16,
      0  => vlen / 16,
      1  => vlen / 8,
      2  => vlen / 4,
      3  => vlen / 2,
    },
    32 => match LMUL_pow {
      -3 => vlen / 32,
      -2 => vlen / 32,
      -1 => vlen / 32,
      0  => vlen / 32,
      1  => vlen / 16,
      2  => vlen / 8,
      3  => vlen / 4,
    },
    64 => match LMUL_pow {
      -3 => vlen / 64,
      -2 => vlen / 64,
      -1 => vlen / 64,
      0  => vlen / 64,
      1  => vlen / 32,
      2  => vlen / 16,
      3  => vlen / 8,
    },
  }
}

// Read a single element of a vector register group (starting at vrid).
val read_single_element : forall 'sew, is_sew_bitsize('sew) . (int('sew), nat, vregidx) -> bits('sew)
function read_single_element(EEW, index, vrid) = {
  assert(EEW <= vlen);
  static_assert(vlen % EEW == 0);

  // Number of EEW-bit elements per vector register.
  let elem_per_reg = vlen / EEW;

  // Register in group. Max LMUL is 8, so this should be in [0, 8).
  let reg_in_group = index / elem_per_reg;
  assert(reg_in_group < 8);

  // Get the actual register in the group that we need to write, and the index into it.
  let vrid = vrid + reg_in_group;
  let index = index % elem_per_reg;
  // Bit offset in register.
  let offset = index * EEW;

  V(vrid)[(offset + EEW - 1) .. offset]
}

$ifndef SYMBOLIC
// The general vreg reading operation with num_elem as max(VLMAX,VLEN/SEW)).
val read_vreg : forall 'n 'sew 'p, 'n >= 0 & is_sew_bitsize('sew) . (int('n), int('sew), int('p), vregidx) -> vector('n, bits('sew))
function read_vreg(num_elem, SEW, LMUL_pow, vrid) = {
  assert_vector_num_elem(num_elem);
  assert_lmul_pow(LMUL_pow);
  let vrid_val = unsigned(vregidx_bits(vrid));
  let LMUL = checked_lmul_group_size(LMUL_pow);
  let vrid_end = vrid_val + LMUL;
  assert(vrid_end <= 32, "Invalid register group: group " ^ dec_str(vrid_val) ^ " ends at " ^ dec_str(vrid_end) ^ " and overflows the largest register number (32).");
  assert(vrid_val % LMUL == 0, "Invalid register group: group " ^ dec_str(vrid_val) ^ " is not a multiple of its EMUL " ^ dec_str(LMUL) ^ ".");

  var result : vector('n, bits('sew)) = vector_init(zeros());

  foreach (i from 0 to (num_elem - 1)) {
    result[i] = read_single_element(SEW, i, vrid)
  };

  result
}
$else
val isla_read_vreg = pure "isla_read_vreg" :
  forall 'n 'sew, 'n >= 0 & is_sew_bitsize('sew) .
  (int('n), int('sew), int, vlenbits, vlenbits, vlenbits, vlenbits, vlenbits, vlenbits, vlenbits, vlenbits) -> vector('n, bits('sew))

val read_vreg_extra : forall 'n 'sew 'p, 'n >= 0 & is_sew_bitsize('sew) . (int('n), int('sew), int('p), vregidx) -> vector('n, bits('sew))
function read_vreg_extra(num_elem, SEW, LMUL_pow, vrid) = {
  let vrid_val = unsigned(vregidx_bits(vrid));
  let LMUL = checked_lmul_group_size(LMUL_pow);
  let vrid_end = vrid_val + LMUL;
  assert(vrid_end <= 32, "Invalid register group: group " ^ dec_str(vrid_val) ^ " ends at " ^ dec_str(vrid_end) ^ " and overflows the largest register number (32).");
  assert(vrid_val % LMUL == 0, "Invalid register group: group " ^ dec_str(vrid_val) ^ " is not a multiple of its EMUL " ^ dec_str(LMUL) ^ ".");
  let zero_vreg : vlenbits = zeros();

  match LMUL {
    1 => isla_read_vreg(num_elem, SEW, 0, V(vrid), zero_vreg, zero_vreg, zero_vreg, zero_vreg, zero_vreg, zero_vreg, zero_vreg),
    2 => isla_read_vreg(num_elem, SEW, 0, V(vrid), V(vregidx_offset(vrid, 0b00001)), zero_vreg, zero_vreg, zero_vreg, zero_vreg, zero_vreg, zero_vreg),
    4 => isla_read_vreg(num_elem, SEW, 0, V(vrid), V(vregidx_offset(vrid, 0b00001)), V(vregidx_offset(vrid, 0b00010)), V(vregidx_offset(vrid, 0b00011)), zero_vreg, zero_vreg, zero_vreg, zero_vreg),
    8 => isla_read_vreg(num_elem, SEW, 0, V(vrid), V(vregidx_offset(vrid, 0b00001)), V(vregidx_offset(vrid, 0b00010)), V(vregidx_offset(vrid, 0b00011)), V(vregidx_offset(vrid, 0b00100)), V(vregidx_offset(vrid, 0b00101)), V(vregidx_offset(vrid, 0b00110)), V(vregidx_offset(vrid, 0b00111))),
    _ => {
      assert(false);
      isla_read_vreg(num_elem, SEW, 0, V(vrid), zero_vreg, zero_vreg, zero_vreg, zero_vreg, zero_vreg, zero_vreg, zero_vreg)
    }
  }
}

val read_vreg_num_elem : forall 'n 'sew 'p, 'n >= 0 & is_sew_bitsize('sew) . (int('n), int('sew), int('p), vregidx) -> vector('n, bits('sew))
function read_vreg_num_elem(num_elem, SEW, LMUL_pow, vrid) = {
  assert_vector_num_elem(num_elem);
  read_vreg_extra(num_elem, SEW, LMUL_pow, vrid)
}

val read_vreg_extra_by_sew : forall 'n 'sew 'p, 'n >= 0 & is_sew_bitsize('sew) . (int('n), int('sew), int('p), vregidx) -> vector('n, bits('sew))
function read_vreg_extra_by_sew(num_elem, SEW, LMUL_pow, vrid) = {
  read_vreg_num_elem(num_elem, SEW, LMUL_pow, vrid)
}

val isla_pack_vreg = pure "isla_pack_vreg" : forall 'n 'sew, 'n >= 0 & is_sew_bitsize('sew) . (int('sew), int, vector('n, bits('sew))) -> vector(8, vlenbits)
val isla_pack_vreg_infer_sew = pure "isla_pack_vreg_infer_sew" : forall 'n 'sew, 'n >= 0 & is_sew_bitsize('sew) . (int, vector('n, bits('sew))) -> vector(8, vlenbits)

// The general vreg reading operation with num_elem as max(VLMAX,VLEN/SEW)).
val read_vreg_default : forall 'n 'sew 'p, 'n >= 0 & is_sew_bitsize('sew) . (int('n), int('sew), int('p), vregidx) -> vector('n, bits('sew))
function read_vreg_default(num_elem, SEW, LMUL_pow, vrid) = {
  assert_vector_num_elem(num_elem);
  assert_lmul_pow(LMUL_pow);
  let vrid_val = unsigned(vregidx_bits(vrid));
  let LMUL = checked_lmul_group_size(LMUL_pow);
  let vrid_end = vrid_val + LMUL;
  assert(vrid_end <= 32, "Invalid register group: group " ^ dec_str(vrid_val) ^ " ends at " ^ dec_str(vrid_end) ^ " and overflows the largest register number (32).");
  assert(vrid_val % LMUL == 0, "Invalid register group: group " ^ dec_str(vrid_val) ^ " is not a multiple of its EMUL " ^ dec_str(LMUL) ^ ".");

  var result : vector('n, bits('sew)) = vector_init(zeros());

  foreach (i from 0 to (num_elem - 1)) {
    result[i] = read_single_element(SEW, i, vrid)
  };

  result
}

val read_vreg : forall 'n 'sew 'p, 'n >= 0 & is_sew_bitsize('sew) . (int('n), int('sew), int('p), vregidx) -> vector('n, bits('sew))
function read_vreg(num_elem, SEW, LMUL_pow, vrid) =
  if __isla_use_extra_ops then read_vreg_extra_by_sew(num_elem, SEW, LMUL_pow, vrid)
  else read_vreg_default(num_elem, SEW, LMUL_pow, vrid)
$endif

// Write a single element of a vector register group (starting at vrid),
// leaving all other elements unchanged.
val write_single_element : forall 'sew, is_sew_bitsize('sew) . (int('sew), nat, vregidx, bits('sew)) -> unit
function write_single_element(EEW, index, vrid, value) = {
  assert(EEW <= vlen);
  static_assert(vlen % EEW == 0);

  // Number of EEW-bit elements per vector register.
  let elem_per_reg = vlen / EEW;

  // Register in group. Max LMUL is 8, so this should be in [0, 8).
  let reg_in_group = index / elem_per_reg;
  assert(reg_in_group < 8);

  // Get the actual register in the group that we need to write, and the index into it.
  let vrid = vrid + reg_in_group;
  let index = index % elem_per_reg;
  // Bit offset in register.
  let offset = index * EEW;

  V(vrid) = [V(vrid) with (offset + EEW - 1) .. offset = value];
}

// Write a complete vector register group.
//
// num_elem: Number of elements in the entire group (ignoring
//           fractional lmul and vl).
// SEW:      Element size in bits.
// LMUL_pow: LMUL exponent; size of the register group.
//           Negative values indicate fractions of a single register, but
//           we still require the full register's worth of elements.
// vrid:     Index of the first register in the group.
// data:     Data of each element.
//
$ifndef SYMBOLIC
val write_vreg : forall 'n 'sew, 'n >= 0 & is_sew_bitsize('sew) . (int('n), int('sew), LMUL_pow, vregidx, vector('n, bits('sew))) -> unit
function write_vreg(num_elem, SEW, LMUL_pow, vrid, vec) = {
  assert_vector_num_elem(num_elem);
  assert_sew(SEW);
  assert_lmul_pow(LMUL_pow);
  // Number of registers in the group (treating fractional lmul as 0).
  let group_size = checked_lmul_group_size(LMUL_pow);

  assert(SEW <= vlen);
  static_assert(vlen % SEW == 0);

  // Number of SEW-bit elements per vector register.
  let elem_per_reg = vlen / SEW;

  // Normally num_elem == group_size * elem_per_reg, however
  // in the specific case of fractional lmul with widening instructions
  // get_num_elem() returns vlen / SEW, but SEW is doubled before
  // feeding into this instruction, so elem_per_reg is half the
  // pre-widening value. Since `group_size` will be unchanged
  // (because max(LMUL_pow, 0) is still 0), we will end up
  // with num_elem == group_size * (elem_per_reg * 2).
  //
  // In that case the second half of the `vec` array will be ignored.
  assert(num_elem == group_size * elem_per_reg | num_elem == 2 * group_size * elem_per_reg);

  foreach (reg_in_group from 0 to (group_size - 1)) {
    var reg_value : vlenbits = zeros();
    foreach (i_elem from 0 to (elem_per_reg - 1)) {
      reg_value[(i_elem * SEW) + SEW - 1 .. (i_elem * SEW)] = vec[reg_in_group * elem_per_reg + i_elem];
    };
    V(vrid + reg_in_group) = reg_value;
  }
}
$else
val write_vreg_default : forall 'n 'sew, 'n >= 0 & is_sew_bitsize('sew) . (int('n), int('sew), LMUL_pow, vregidx, vector('n, bits('sew))) -> unit
function write_vreg_default(num_elem, SEW, LMUL_pow, vrid, vec) = {
  assert_vector_num_elem(num_elem);
  assert_sew(SEW);
  assert_lmul_pow(LMUL_pow);
  // Number of registers in the group (treating fractional lmul as 0).
  let group_size = checked_lmul_group_size(LMUL_pow);

  assert(SEW <= vlen);
  static_assert(vlen % SEW == 0);

  // Number of SEW-bit elements per vector register.
  let elem_per_reg = vlen / SEW;

  // Normally num_elem == group_size * elem_per_reg, however
  // in the specific case of fractional lmul with widening instructions
  // get_num_elem() returns vlen / SEW, but SEW is doubled before
  // feeding into this instruction, so elem_per_reg is half the
  // pre-widening value. Since `group_size` will be unchanged
  // (because max(LMUL_pow, 0) is still 0), we will end up
  // with num_elem == group_size * (elem_per_reg * 2).
  //
  // In that case the second half of the `vec` array will be ignored.
  assert(num_elem == group_size * elem_per_reg | num_elem == 2 * group_size * elem_per_reg);

  foreach (reg_in_group from 0 to (group_size - 1)) {
    var reg_value : vlenbits = zeros();
    foreach (i_elem from 0 to (elem_per_reg - 1)) {
      reg_value[(i_elem * SEW) + SEW - 1 .. (i_elem * SEW)] = vec[reg_in_group * elem_per_reg + i_elem];
    };
    V(vrid + reg_in_group) = reg_value;
  }
}

val write_vreg_extra : forall 'n 'sew, 'n >= 0 & is_sew_bitsize('sew) . (int('n), int('sew), LMUL_pow, vregidx, vector('n, bits('sew))) -> unit
function write_vreg_extra(num_elem, SEW, LMUL_pow, vrid, vec) = {
  assert_vector_num_elem(num_elem);
  assert_sew(SEW);
  assert_lmul_pow(LMUL_pow);
  let checked_SEW = checked_sew_value(SEW);
  let group_size = checked_lmul_group_size(LMUL_pow);
  assert(checked_SEW <= vlen);
  static_assert(vlen % checked_SEW == 0);
  let elem_per_reg = vlen / checked_SEW;
  assert(num_elem == group_size * elem_per_reg | num_elem == 2 * group_size * elem_per_reg);
  let packed : vector(8, vlenbits) = isla_pack_vreg_infer_sew(vlen, vec);
  V(vrid) = packed[0];
  if group_size > 1 then V(vrid + 1) = packed[1];
  if group_size > 2 then V(vrid + 2) = packed[2];
  if group_size > 3 then V(vrid + 3) = packed[3];
  if group_size > 4 then V(vrid + 4) = packed[4];
  if group_size > 5 then V(vrid + 5) = packed[5];
  if group_size > 6 then V(vrid + 6) = packed[6];
  if group_size > 7 then V(vrid + 7) = packed[7]
}

val write_vreg : forall 'n 'sew, 'n >= 0 & is_sew_bitsize('sew) . (int('n), int('sew), LMUL_pow, vregidx, vector('n, bits('sew))) -> unit
function write_vreg(num_elem, SEW, LMUL_pow, vrid, vec) =
  if __isla_use_extra_ops then write_vreg_extra(num_elem, SEW, LMUL_pow, vrid, vec)
  else write_vreg_default(num_elem, SEW, LMUL_pow, vrid, vec)
$endif

// Mask register reading operation with num_elem as max(VLMAX,vlen/SEW)).
val read_vmask : forall 'n, 0 < 'n <= vlen . (int('n), bits(1), vregidx) -> bits('n)
function read_vmask(num_elem, vm, vrid) = {
  let num_elem = checked_vector_num_elem_value(num_elem);
  if vm == 0b1 then ones() else ones('n - num_elem) @ V(vrid)[num_elem - 1 .. 0]
}

// This is a special version of read_vmask for carry/borrow instructions, where vm=1 means no carry.
val read_vmask_carry : forall 'n, 0 < 'n <= vlen . (int('n), bits(1), vregidx) -> bits('n)
function read_vmask_carry(num_elem, vm, vrid) = {
  let num_elem = checked_vector_num_elem_value(num_elem);
  if vm == 0b1 then zeros() else zeros('n - num_elem) @ V(vrid)[num_elem - 1 .. 0]
}

// Mask register writing operation with num_elem as max(VLMAX,vlen/SEW))
val write_vmask : forall 'n, 'n > 0. (int('n), vregidx, bits('n)) -> unit
function write_vmask(num_elem, vrid, v) = {
  // TODO: This should be part of the type signature.
  assert(0 < num_elem & num_elem <= vlen);
  let num_elem = checked_vector_num_elem_value(num_elem);

  // Mask tail is always agnostic. Currently we always
  // leave it undisturbed.
  // TODO: Configuration support for ones/undisturbed.
  V(vrid) = [V(vrid) with (num_elem - 1) .. 0 = v]
}
