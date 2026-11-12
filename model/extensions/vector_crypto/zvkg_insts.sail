// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

function clause currentlyEnabled(Ext_Zvkg) = hartSupports(Ext_Zvkg) & currentlyEnabled(Ext_Zve32x)

union clause instruction = VGHSH_VV : (vregidx, vregidx, vregidx)

$[wavedrom "_ _ _ OPMVV _ OP-VE"]
mapping clause encdec = VGHSH_VV(vs2, vs1, vd)
  <-> 0b1011001 @ encdec_vreg(vs2) @ encdec_vreg(vs1) @ 0b010 @ encdec_vreg(vd) @ 0b1110111
  when currentlyEnabled(Ext_Zvkg) & get_sew() == 32 & zvk_check_encdec(128, 4)

function clause execute VGHSH_VV(vs2, vs1, vd) = {
  let SEW      = get_sew();
  let LMUL_pow = get_lmul_pow();
  let num_elem = get_num_elem(LMUL_pow, SEW);

  if not(valid_reg_group(vs1, LMUL_pow)) |
     not(valid_reg_group(vs2, LMUL_pow)) |
     not(valid_reg_group(vd, LMUL_pow))
  then return Illegal_Instruction();

  assert(SEW == 32);
  assert_sew_32(SEW);

  let vs2_val = read_vreg(num_elem, SEW, LMUL_pow, vs2);
  let vs1_val = read_vreg(num_elem, SEW, LMUL_pow, vs1);
  let vd_val  = read_vreg(num_elem, SEW, LMUL_pow, vd);

  let eg_len   = (unsigned(vl) / 4);
  let eg_start = (unsigned(vstart) / 4);

  foreach (i from eg_start to (eg_len - 1)) {
    assert(i * 4 + 3 < num_elem);

    let Y : bits(128) = get_velem_quad(vd_val, i);
    let X : bits(128) = get_velem_quad(vs1_val, i);
    let H : bits(128) = brev8(get_velem_quad(vs2_val, i));

    let S : bits(128) = brev8(Y ^ X);
    let Z : bits(128) = gf2_poly_mul_mod(S, H, 0x00000000000000000000000000000087);

    write_velem_quad(vd, SEW, brev8(Z), i);
  };

  set_vstart(zeros());
  RETIRE_SUCCESS
}

mapping clause assembly = VGHSH_VV(vs2, vs1, vd)
  <-> "vghsh.vv" ^ spc() ^ vreg_name(vd) ^ sep() ^ vreg_name(vs2) ^ sep() ^ vreg_name(vs1)

union clause instruction = VGMUL_VV : (vregidx, vregidx)

$[wavedrom "_ _ _ OPMVV _ OP-VE"]
mapping clause encdec = VGMUL_VV(vs2, vd)
  <-> 0b1010001 @ encdec_vreg(vs2) @ 0b10001 @ 0b010 @ encdec_vreg(vd) @ 0b1110111
  when currentlyEnabled(Ext_Zvkg) & get_sew() == 32 & zvk_check_encdec(128, 4)

function clause execute VGMUL_VV(vs2, vd) = {
  let SEW      = get_sew();
  let LMUL_pow = get_lmul_pow();
  let num_elem = get_num_elem(LMUL_pow, SEW);

  if not(valid_reg_group(vs2, LMUL_pow)) |
     not(valid_reg_group(vd, LMUL_pow))
  then return Illegal_Instruction();

  assert(SEW == 32);
  assert_sew_32(SEW);

  let vs2_val = read_vreg(num_elem, SEW, LMUL_pow, vs2);
  let vd_val  = read_vreg(num_elem, SEW, LMUL_pow, vd);

  let eg_len   = (unsigned(vl) / 4);
  let eg_start = (unsigned(vstart) / 4);

  foreach (i from eg_start to (eg_len - 1)) {
    assert(i * 4 + 3 < num_elem);

    let Y : bits(128) = brev8(get_velem_quad(vd_val, i));
    let H : bits(128) = brev8(get_velem_quad(vs2_val, i));
    let Z : bits(128) = gf2_poly_mul_mod(Y, H, 0x00000000000000000000000000000087);

    write_velem_quad(vd, SEW, brev8(Z), i);
  };

  set_vstart(zeros());
  RETIRE_SUCCESS
}

mapping clause assembly = VGMUL_VV(vs2, vd)
  <-> "vgmul.vv" ^ spc() ^ vreg_name(vd) ^ sep() ^ vreg_name(vs2)
