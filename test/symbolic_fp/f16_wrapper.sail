// Dedicated f16 wrapper entry points. The test driver checks that each
// SYMBOLIC body exists in IR and compares its result with SoftFloat.
$ifdef SYMBOLIC
function f16_wrapper_binary(rm : bits_rm, a : bits_H, b : bits_H) -> (bits_fflags, bits_H) =
  riscv_f16Add(rm, a, b)

function f16_wrapper_compare(a : bits_H, b : bits_H) -> (bits_fflags, bool) =
  riscv_f16Eq(a, b)

function f16_wrapper_unary(rm : bits_rm, a : bits_H) -> (bits_fflags, bits_H) =
  riscv_f16Sqrt(rm, a)

function f16_wrapper_ternary(rm : bits_rm, a : bits_H, b : bits_H, c : bits_H) -> (bits_fflags, bits_H) =
  riscv_f16MulAdd(rm, a, b, c)

function f16_wrapper_unknown_add() -> (bits_rm, bits_H, bits_H, bits_fflags, bits_H) = {
  let rm : bits_rm = undefined;
  let a : bits_H = undefined;
  let b : bits_H = undefined;
  let (flags, result) = riscv_f16Add(rm, a, b);
  (rm, a, b, flags, result)
}

function f16_wrapper_unknown_eq() -> (bits_H, bits_H, bits_fflags, bool) = {
  let a : bits_H = undefined;
  let b : bits_H = undefined;
  let (flags, result) = riscv_f16Eq(a, b);
  (a, b, flags, result)
}

function f16_wrapper_unknown_i32_to_f16() -> (bits_rm, bits_W, bits_fflags, bits_H) = {
  let rm : bits_rm = undefined;
  let a : bits_W = undefined;
  let (flags, result) = riscv_i32ToF16(rm, a);
  (rm, a, flags, result)
}
$endif

function f16_wrapper_cpp_probe(rm : bits_rm, a : bits_H, b : bits_H) -> (bits_fflags, bits_H) =
  riscv_f16Add(rm, a, b)
