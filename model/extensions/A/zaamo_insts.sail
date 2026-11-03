// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

function clause currentlyEnabled(Ext_A) = hartSupports(Ext_A) & misa[A] == 0b1 // TODO: Move currentlyEnabled(Ext_A) to a more central file
function clause currentlyEnabled(Ext_Zaamo) = hartSupports(Ext_Zaamo) | currentlyEnabled(Ext_A)
function clause currentlyEnabled(Ext_Zabha) = hartSupports(Ext_Zabha) & currentlyEnabled(Ext_Zaamo)
function clause currentlyEnabled(Ext_Zacas) = hartSupports(Ext_Zacas) & currentlyEnabled(Ext_Zaamo)

// Zaamo defines AMOs for 32-bit and 64-bit.
// Zabha defines AMOs for 8-bit and 16-bit.
//
// The Zacas extension adds a CAS operation which support 32, 64
// and 128-bit operands. Only sizes up to XLEN*2 are supported
// (so 128-bit is RV64-only). When XLEN*2 is used the operands
// are stored in even-numbered register pairs.
//
// If Zabha and Zacas are implemented then CAS supports 8 and
// 16-bit operands.
//
private function amo_encoding_valid(width : word_width_wide, op : amoop, Regidx(rs2) : regidx, Regidx(rd) : regidx) -> bool =
  // If AMOCAS, check that extension is enabled.
  (if op == AMOCAS then currentlyEnabled(Ext_Zacas) else currentlyEnabled(Ext_Zaamo))
  &
  // Check the size and register alignment.
  (if width < 4 then currentlyEnabled(Ext_Zabha) else (
    width <= xlen_bytes | (
      (op == AMOCAS & width <= xlen_bytes * 2)
      &
      (if   rs2[0] == 0b1 | rd[0] == 0b1
      then match amocas_odd_register_reserved_behavior {
        AMOCAS_Fatal   => reserved_behavior("AMOCAS.D/Q used an odd-numbered register (rs2 = " ^ dec_str(unsigned(rs2)) ^ ", rd = " ^ dec_str(unsigned(rd)) ^ ")."),
        AMOCAS_Illegal => false,
      }
      else true)
    )))

// *****************************************************************

union clause instruction = AMO : (amoop, bool, bool, regidx, regidx, word_width_wide, regidx)

mapping encdec_amoop : amoop <-> bits(5) = {
  AMOSWAP <-> 0b00001,
  AMOADD  <-> 0b00000,
  AMOXOR  <-> 0b00100,
  AMOAND  <-> 0b01100,
  AMOOR   <-> 0b01000,
  AMOMIN  <-> 0b10000,
  AMOMAX  <-> 0b10100,
  AMOMINU <-> 0b11000,
  AMOMAXU <-> 0b11100,
  AMOCAS  <-> 0b00101,
}

$ifdef SYMBOLIC
val amo_layout : (amoop, bool, bool, regidx, regidx, word_width_wide, regidx) <-> bits(32)

function amo_layout_forwards((op, aq, rl, rs2, rs1, size, rd)) =
  encdec_amoop_forwards(op) @ bool_bit_forwards(aq) @ bool_bit_forwards(rl) @
  encdec_reg_forwards(rs2) @ encdec_reg_forwards(rs1) @
  width_enc_wide_forwards(size) @ encdec_reg_forwards(rd) @ 0b0101111

function amo_layout_forwards_matches(_) = true

function amo_layout_backwards(word) = match word[6..0] {
  0b0101111 =>
    (encdec_amoop_backwards(word[31..27]),
     bool_bit_backwards(word[26..26]), bool_bit_backwards(word[25..25]),
     encdec_reg_backwards(word[24..20]), encdec_reg_backwards(word[19..15]),
     width_enc_wide_backwards(word[14..12]), encdec_reg_backwards(word[11..7])),
}

function amo_layout_op_matches(op : bits(5)) -> bool =
  strict_or_bool(
    strict_or_bool(
      strict_or_bool(eq_anything(op, 0b00001), eq_anything(op, 0b00000)),
      strict_or_bool(eq_anything(op, 0b00100), eq_anything(op, 0b01100))),
    strict_or_bool(
      strict_or_bool(eq_anything(op, 0b01000), eq_anything(op, 0b10000)),
      strict_or_bool(
        strict_or_bool(eq_anything(op, 0b10100), eq_anything(op, 0b11000)),
        strict_or_bool(eq_anything(op, 0b11100), eq_anything(op, 0b00101)))))

function amo_layout_width_matches(width : bits(3)) -> bool =
  strict_or_bool(
    strict_or_bool(eq_anything(width, 0b000), eq_anything(width, 0b001)),
    strict_or_bool(
      strict_or_bool(eq_anything(width, 0b010), eq_anything(width, 0b011)),
      eq_anything(width, 0b100)))

function amo_layout_reg_matches(reg : bits(5)) -> bool =
  strict_or_bool(not_bool(base_E_enabled), eq_anything(reg[4], 0b0))

function amo_layout_backwards_matches(word) =
  strict_and_bool(
    strict_and_bool(eq_anything(word[6..0], 0b0101111),
                    amo_layout_op_matches(word[31..27])),
    strict_and_bool(
      amo_layout_width_matches(word[14..12]),
      strict_and_bool(
        amo_layout_reg_matches(word[24..20]),
        strict_and_bool(amo_layout_reg_matches(word[19..15]),
                        amo_layout_reg_matches(word[11..7])))))
$endif

$ifdef SYMBOLIC
mapping clause encdec = AMO(op, aq, rl, rs2, rs1, size, rd)
  <-> amo_layout((op, aq, rl, rs2, rs1, size, rd))
  when amo_encoding_valid(size, op, rs2, rd)
$else
mapping clause encdec = AMO(op, aq, rl, rs2, rs1, size, rd)
  <-> encdec_amoop(op) @ bool_bit(aq) @ bool_bit(rl) @ encdec_reg(rs2) @ encdec_reg(rs1) @ width_enc_wide(size) @ encdec_reg(rd) @ 0b0101111
  when amo_encoding_valid(size, op, rs2, rd)
$endif

val execute_amo_width : forall 'width, 'width in {1, 2, 4, 8, 16}.
  (amoop, bool, bool, regidx, regidx, int('width), regidx) -> ExecutionResult
function execute_amo_width(op, aq, rl, rs2, rs1, width, rd) = {
  // This is checked during decoding.
  assert(width <= xlen_bytes * 2);

  let access = Atomic(op, Data, Data);

  // Get the address, X(rs1) (no offset).
  // Some extensions perform additional checks on address validity.
  let vaddr : virtaddr = match ext_data_get_addr(rs1, zeros(), access, width) {
    Ext_DataAddr_Error(e)  => return Ext_DataAddr_Check_Failure(e),
    Ext_DataAddr_OK(vaddr) => vaddr,
  };

  if not(is_aligned_addr(vaddr, width))
  then return Memory_Exception(vaddr, E_SAMO_Addr_Align());

  let addr : physaddr = match translateAddr(vaddr, access) {
    Err(e, _) => return Memory_Exception(vaddr, e),
    Ok(addr, _) => addr,
  };

  // AMOCAS.D for RV32 and AMOCAS.Q for RV64 operate on a pair of
  // registers. When the first register of a register pair is
  // x0, then both halves of the pair read/write as zero.
  let rs2_val : bits('width * 8) = if width <= xlen_bytes then trunc(X(rs2)) else trunc(X_pair(rs2));

  let loaded : bits('width * 8) = match mem_write_ea(addr, width, aq & rl, rl, true) {
    Err(e) => return Memory_Exception(vaddr, e),
    Ok(_)  => match mem_read(access, addr, width, aq, aq & rl, true) {
      Err(e)     => return Memory_Exception(vaddr, e),
      Ok(loaded) => loaded,
    },
  };

  let result : bits('width * 8) = match op {
    AMOSWAP => rs2_val,
    AMOADD  => rs2_val + loaded,
    AMOXOR  => rs2_val ^ loaded,
    AMOAND  => rs2_val & loaded,
    AMOOR   => rs2_val | loaded,
    AMOMIN  => if rs2_val <_s loaded then rs2_val else loaded,
    AMOMAX  => if rs2_val >_s loaded then rs2_val else loaded,
    AMOMINU => if rs2_val <_u loaded then rs2_val else loaded,
    AMOMAXU => if rs2_val >_u loaded then rs2_val else loaded,
    // If it *does* store a value, CAS always stores rs2.
    AMOCAS  => rs2_val,
  };

  // All operations except CAS where loaded != X(rd) write their value back.
  if op == AMOCAS & loaded != (if width <= xlen_bytes then trunc(X(rd)) else trunc(X_pair(rd))) then {
    // Compared, but didn't swap.
    if width <= xlen_bytes
    then X(rd) = sign_extend(loaded)
    else X_pair(rd) = sign_extend(loaded);
    RETIRE_SUCCESS
  } else match mem_write_value(addr, width, sign_extend(result), aq & rl, rl, true) {
    Ok(true)  => {
      if width <= xlen_bytes
      then X(rd) = sign_extend(loaded)
      else X_pair(rd) = sign_extend(loaded);
      RETIRE_SUCCESS
    },
    Ok(false) => internal_error(__FILE__, __LINE__, "AMO got false from mem_write_value"),
    Err(e)    => Memory_Exception(vaddr, e),
  }
}

// NOTE: Currently, we only EA if address translation is successful.
// This may need revisiting.
$[split op]
function clause execute AMO(op, aq, rl, rs2, rs1, width, rd) = {
  match width {
    1  => execute_amo_width(op, aq, rl, rs2, rs1, 1, rd),
    2  => execute_amo_width(op, aq, rl, rs2, rs1, 2, rd),
    4  => execute_amo_width(op, aq, rl, rs2, rs1, 4, rd),
    8  => execute_amo_width(op, aq, rl, rs2, rs1, 8, rd),
    16 => execute_amo_width(op, aq, rl, rs2, rs1, 16, rd),
  }
}

mapping amo_mnemonic : amoop <-> string = {
  AMOSWAP <-> "amoswap",
  AMOADD  <-> "amoadd",
  AMOXOR  <-> "amoxor",
  AMOAND  <-> "amoand",
  AMOOR   <-> "amoor",
  AMOMIN  <-> "amomin",
  AMOMAX  <-> "amomax",
  AMOMINU <-> "amominu",
  AMOMAXU <-> "amomaxu",
  AMOCAS  <-> "amocas",
}

mapping clause assembly = AMO(op, aq, rl, rs2, rs1, width, rd)
  <-> amo_mnemonic(op) ^ "." ^ width_mnemonic_wide(width) ^ maybe_aqrl(aq, rl) ^ spc() ^ reg_name(rd) ^ sep() ^ reg_name(rs2) ^ sep() ^ "(" ^ reg_name(rs1) ^ ")"
