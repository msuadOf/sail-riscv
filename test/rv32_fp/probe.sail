// Isolated RV32 regression probes. Each instruction enters through the actual
// backwards decoder; no instruction constructor is supplied to execute.

val rv32_fp_probe_fmvh : unit -> (instruction, ExecutionResult, xlenbits, bits(5))
function rv32_fp_probe_fmvh() = {
  fcsr[FFLAGS] = 0b00001;
  F_D(Fregidx(0b00001)) = 0x89abcdef01234567;
  X(Regidx(to_bits(10))) = to_bits(unsigned(0x13572468));
  let decoded = ext_decode(0xe2108553);
  let retired = execute(decoded);
  (decoded, retired, X(Regidx(to_bits(10))), fcsr[FFLAGS])
}

val rv32_fp_probe_fmvp : unit -> (instruction, ExecutionResult, bits(64), bits(5))
function rv32_fp_probe_fmvp() = {
  fcsr[FFLAGS] = 0b00001;
  X(Regidx(to_bits(11))) = to_bits(unsigned(0x01234567));
  X(Regidx(to_bits(12))) = to_bits(unsigned(0x89abcdef));
  F_D(Fregidx(0b00010)) = 0x0123456789abcdef;
  let decoded = ext_decode(0xb2c58153);
  let retired = execute(decoded);
  (decoded, retired, F_D(Fregidx(0b00010)), fcsr[FFLAGS])
}

val rv32_fp_probe_c_flw : unit -> instruction
function rv32_fp_probe_c_flw() = ext_decode_compressed(0x6000)
val rv32_fp_probe_c_flwsp : unit -> instruction
function rv32_fp_probe_c_flwsp() = ext_decode_compressed(0x6082)
val rv32_fp_probe_c_fsw : unit -> instruction
function rv32_fp_probe_c_fsw() = ext_decode_compressed(0xe000)
val rv32_fp_probe_c_fswsp : unit -> instruction
function rv32_fp_probe_c_fswsp() = ext_decode_compressed(0xe006)
