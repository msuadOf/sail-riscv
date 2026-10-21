// Every input is unknown when a pure helper is entered.
$ifdef SYMBOLIC
function f32_unknown_riscv_f32Eq() -> (bits_fflags, bool) = {
  let a : bits_S = undefined;
  let b : bits_S = undefined;
  riscv_f32Eq(a, b)
}

function f32_unknown_riscv_f32Lt() -> (bits_fflags, bool) = {
  let a : bits_S = undefined;
  let b : bits_S = undefined;
  riscv_f32Lt(a, b)
}

function f32_unknown_riscv_f32Lt_quiet() -> (bits_fflags, bool) = {
  let a : bits_S = undefined;
  let b : bits_S = undefined;
  riscv_f32Lt_quiet(a, b)
}

function f32_unknown_riscv_f32Le() -> (bits_fflags, bool) = {
  let a : bits_S = undefined;
  let b : bits_S = undefined;
  riscv_f32Le(a, b)
}

function f32_unknown_riscv_f32Le_quiet() -> (bits_fflags, bool) = {
  let a : bits_S = undefined;
  let b : bits_S = undefined;
  riscv_f32Le_quiet(a, b)
}

function f32_unknown_riscv_f32Add() -> (bits_fflags, bits_S) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  let b : bits_S = undefined;
  riscv_f32Add(rm, a, b)
}

function f32_unknown_riscv_f32Sub() -> (bits_fflags, bits_S) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  let b : bits_S = undefined;
  riscv_f32Sub(rm, a, b)
}

function f32_unknown_riscv_f32Mul() -> (bits_fflags, bits_S) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  let b : bits_S = undefined;
  riscv_f32Mul(rm, a, b)
}

function f32_unknown_riscv_f32Div() -> (bits_fflags, bits_S) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  let b : bits_S = undefined;
  riscv_f32Div(rm, a, b)
}

function f32_unknown_riscv_f32Sqrt() -> (bits_fflags, bits_S) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  riscv_f32Sqrt(rm, a)
}

function f32_unknown_riscv_f32MulAdd() -> (bits_fflags, bits_S) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  let b : bits_S = undefined;
  let c : bits_S = undefined;
  riscv_f32MulAdd(rm, a, b, c)
}

function f32_unknown_riscv_f32roundToInt() -> (bits_fflags, bits_S) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  let exact : bool = undefined;
  riscv_f32roundToInt(rm, a, exact)
}

function f32_unknown_riscv_f32ToI32() -> (bits_fflags, bits_W) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  riscv_f32ToI32(rm, a)
}

function f32_unknown_riscv_f32ToUi32() -> (bits_fflags, bits_WU) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  riscv_f32ToUi32(rm, a)
}

function f32_unknown_riscv_f32ToI64() -> (bits_fflags, bits_L) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  riscv_f32ToI64(rm, a)
}

function f32_unknown_riscv_f32ToUi64() -> (bits_fflags, bits_LU) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  riscv_f32ToUi64(rm, a)
}

function f32_unknown_riscv_i32ToF32() -> (bits_fflags, bits_S) = {
  let rm : bits_rm = undefined;
  let a : bits_W = undefined;
  riscv_i32ToF32(rm, a)
}

function f32_unknown_riscv_ui32ToF32() -> (bits_fflags, bits_S) = {
  let rm : bits_rm = undefined;
  let a : bits_WU = undefined;
  riscv_ui32ToF32(rm, a)
}

function f32_unknown_riscv_i64ToF32() -> (bits_fflags, bits_S) = {
  let rm : bits_rm = undefined;
  let a : bits_L = undefined;
  riscv_i64ToF32(rm, a)
}

function f32_unknown_riscv_ui64ToF32() -> (bits_fflags, bits_S) = {
  let rm : bits_rm = undefined;
  let a : bits_LU = undefined;
  riscv_ui64ToF32(rm, a)
}

function f32_unknown_riscv_f32ToF16() -> (bits_fflags, bits_H) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  riscv_f32ToF16(rm, a)
}

function f32_unknown_riscv_f32ToF64() -> (bits_fflags, bits_D) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  riscv_f32ToF64(rm, a)
}

function f32_unknown_riscv_f32ToBF16() -> (bits_fflags, bits_BF16) = {
  let rm : bits_rm = undefined;
  let a : bits_S = undefined;
  riscv_f32ToBF16(rm, a)
}

$endif
