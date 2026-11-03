// Preserve calls to each migrated f64 helper in a compact isolated IR.
function f64_compare_probe(a : bits_D, b : bits_D) -> (bits_fflags, bool) =
  riscv_f64Eq(a, b)

function f64_arithmetic_probe(rm : bits_rm, a : bits_D, b : bits_D, c : bits_D) -> (bits_fflags, bits_D) =
  riscv_f64MulAdd(rm, a, b, c)

// Return the unknown inputs alongside outputs for SAT/UNSAT equivalence checks.
function f64_unknown_riscv_f64Eq_inputs() -> (bits_D, bits_D, bits_fflags, bool) = {
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  let (flags, result) = riscv_f64Eq(a, b);
  (a, b, flags, result)
}

function f64_unknown_riscv_f64Lt_inputs() -> (bits_D, bits_D, bits_fflags, bool) = {
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  let (flags, result) = riscv_f64Lt(a, b);
  (a, b, flags, result)
}

function f64_unknown_riscv_f64Lt_quiet_inputs() -> (bits_D, bits_D, bits_fflags, bool) = {
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  let (flags, result) = riscv_f64Lt_quiet(a, b);
  (a, b, flags, result)
}

function f64_unknown_riscv_f64Le_inputs() -> (bits_D, bits_D, bits_fflags, bool) = {
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  let (flags, result) = riscv_f64Le(a, b);
  (a, b, flags, result)
}

function f64_unknown_riscv_f64Le_quiet_inputs() -> (bits_D, bits_D, bits_fflags, bool) = {
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  let (flags, result) = riscv_f64Le_quiet(a, b);
  (a, b, flags, result)
}

function f64_unknown_riscv_f64Add_inputs() -> (bits_rm, bits_D, bits_D, bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  let (flags, result) = riscv_f64Add(rm, a, b);
  (rm, a, b, flags, result)
}

function f64_unknown_riscv_f64Sub_inputs() -> (bits_rm, bits_D, bits_D, bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  let (flags, result) = riscv_f64Sub(rm, a, b);
  (rm, a, b, flags, result)
}

function f64_unknown_riscv_f64Mul_inputs() -> (bits_rm, bits_D, bits_D, bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  let (flags, result) = riscv_f64Mul(rm, a, b);
  (rm, a, b, flags, result)
}

function f64_unknown_riscv_f64Div_inputs() -> (bits_rm, bits_D, bits_D, bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  let (flags, result) = riscv_f64Div(rm, a, b);
  (rm, a, b, flags, result)
}

function f64_unknown_riscv_f64Sqrt_inputs() -> (bits_rm, bits_D, bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let (flags, result) = riscv_f64Sqrt(rm, a);
  (rm, a, flags, result)
}

function f64_unknown_riscv_f64MulAdd_inputs() -> (bits_rm, bits_D, bits_D, bits_D, bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  let c : bits_D = undefined;
  let (flags, result) = riscv_f64MulAdd(rm, a, b, c);
  (rm, a, b, c, flags, result)
}

function f64_unknown_riscv_f64roundToInt_inputs() -> (bits_rm, bits_D, bool, bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let raise_inexact : bool = undefined;
  let (flags, result) = riscv_f64roundToInt(rm, a, raise_inexact);
  (rm, a, raise_inexact, flags, result)
}

function f64_unknown_riscv_f64ToI32_inputs() -> (bits_rm, bits_D, bits_fflags, bits_W) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let (flags, result) = riscv_f64ToI32(rm, a);
  (rm, a, flags, result)
}

function f64_unknown_riscv_f64ToUi32_inputs() -> (bits_rm, bits_D, bits_fflags, bits_WU) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let (flags, result) = riscv_f64ToUi32(rm, a);
  (rm, a, flags, result)
}

function f64_unknown_riscv_f64ToI64_inputs() -> (bits_rm, bits_D, bits_fflags, bits_L) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let (flags, result) = riscv_f64ToI64(rm, a);
  (rm, a, flags, result)
}

function f64_unknown_riscv_f64ToUi64_inputs() -> (bits_rm, bits_D, bits_fflags, bits_LU) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let (flags, result) = riscv_f64ToUi64(rm, a);
  (rm, a, flags, result)
}

function f64_unknown_riscv_i32ToF64_inputs() -> (bits_rm, bits_W, bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_W = undefined;
  let (flags, result) = riscv_i32ToF64(rm, a);
  (rm, a, flags, result)
}

function f64_unknown_riscv_ui32ToF64_inputs() -> (bits_rm, bits_WU, bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_WU = undefined;
  let (flags, result) = riscv_ui32ToF64(rm, a);
  (rm, a, flags, result)
}

function f64_unknown_riscv_i64ToF64_inputs() -> (bits_rm, bits_L, bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_L = undefined;
  let (flags, result) = riscv_i64ToF64(rm, a);
  (rm, a, flags, result)
}

function f64_unknown_riscv_ui64ToF64_inputs() -> (bits_rm, bits_LU, bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_LU = undefined;
  let (flags, result) = riscv_ui64ToF64(rm, a);
  (rm, a, flags, result)
}

function f64_unknown_riscv_f64ToF16_inputs() -> (bits_rm, bits_D, bits_fflags, bits_H) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let (flags, result) = riscv_f64ToF16(rm, a);
  (rm, a, flags, result)
}

function f64_unknown_riscv_f64ToF32_inputs() -> (bits_rm, bits_D, bits_fflags, bits_S) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let (flags, result) = riscv_f64ToF32(rm, a);
  (rm, a, flags, result)
}


// Unknown-input entry points expose data-dependent execution forks.
function f64_unknown_riscv_f64Eq() -> (bits_fflags, bool) = {
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  riscv_f64Eq(a, b)
}

function f64_unknown_riscv_f64Lt() -> (bits_fflags, bool) = {
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  riscv_f64Lt(a, b)
}

function f64_unknown_riscv_f64Lt_quiet() -> (bits_fflags, bool) = {
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  riscv_f64Lt_quiet(a, b)
}

function f64_unknown_riscv_f64Le() -> (bits_fflags, bool) = {
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  riscv_f64Le(a, b)
}

function f64_unknown_riscv_f64Le_quiet() -> (bits_fflags, bool) = {
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  riscv_f64Le_quiet(a, b)
}

function f64_unknown_riscv_f64Add() -> (bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  riscv_f64Add(rm, a, b)
}

function f64_unknown_riscv_f64Sub() -> (bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  riscv_f64Sub(rm, a, b)
}

function f64_unknown_riscv_f64Mul() -> (bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  riscv_f64Mul(rm, a, b)
}

function f64_unknown_riscv_f64Div() -> (bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  riscv_f64Div(rm, a, b)
}

function f64_unknown_riscv_f64Sqrt() -> (bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  riscv_f64Sqrt(rm, a)
}

function f64_unknown_riscv_f64MulAdd() -> (bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let b : bits_D = undefined;
  let c : bits_D = undefined;
  riscv_f64MulAdd(rm, a, b, c)
}

function f64_unknown_riscv_f64roundToInt() -> (bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  let raise_inexact : bool = undefined;
  riscv_f64roundToInt(rm, a, raise_inexact)
}

function f64_unknown_riscv_f64ToI32() -> (bits_fflags, bits_W) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  riscv_f64ToI32(rm, a)
}

function f64_unknown_riscv_f64ToUi32() -> (bits_fflags, bits_WU) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  riscv_f64ToUi32(rm, a)
}

function f64_unknown_riscv_f64ToI64() -> (bits_fflags, bits_L) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  riscv_f64ToI64(rm, a)
}

function f64_unknown_riscv_f64ToUi64() -> (bits_fflags, bits_LU) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  riscv_f64ToUi64(rm, a)
}

function f64_unknown_riscv_i32ToF64() -> (bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_W = undefined;
  riscv_i32ToF64(rm, a)
}

function f64_unknown_riscv_ui32ToF64() -> (bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_WU = undefined;
  riscv_ui32ToF64(rm, a)
}

function f64_unknown_riscv_i64ToF64() -> (bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_L = undefined;
  riscv_i64ToF64(rm, a)
}

function f64_unknown_riscv_ui64ToF64() -> (bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_LU = undefined;
  riscv_ui64ToF64(rm, a)
}

function f64_unknown_riscv_f64ToF16() -> (bits_fflags, bits_H) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  riscv_f64ToF16(rm, a)
}

function f64_unknown_riscv_f64ToF32() -> (bits_fflags, bits_S) = {
  let rm : bits_rm = undefined;
  let a : bits_D = undefined;
  riscv_f64ToF32(rm, a)
}
