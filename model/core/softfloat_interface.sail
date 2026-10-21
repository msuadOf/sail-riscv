// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// ***************************************************************
// This file lists all the external Berkeley softfloat functions
// invoked from the Sail spec for RISC-V floating point extensions.
//
// Each of these functions corresponds to one in 'SoftFloat.hs'
// in    https://github.com/GaloisInc/softfloat-hs.git
// written by Ben Selfridge,
// which is a set of pure-functional Haskell wrappers on the
// Berkely softfloat C library written by John Hauser.

// ***************************************************************
// All arguments and results have one of these types

type bits_rm     = bits(3)    // Rounding mode
type bits_fflags = bits(5)    // Accrued exceptions: NV,DZ,OF,UF,NX
type bits_BF16   = bits(16)   // BFloat16-precision float value
type bits_H      = bits(16)   // Half-precision float value
type bits_S      = bits(32)   // Single-precision float value
type bits_D      = bits(64)   // Double-precision float value

type bits_W      = bits(32)   // Signed integer
type bits_WU     = bits(32)   // Unsigned integer

type bits_L      = bits(64)   // Signed integer
type bits_LU     = bits(64)   // Unsigned integer

// ****************************************************************
// ADD/SUB/MUL/DIV

val riscv_f16Add = pure {lem: "softfloat_f16_add"} : (bits_rm, bits_H, bits_H) -> (bits_fflags, bits_H)
val riscv_f16Sub = pure {lem: "softfloat_f16_sub"} : (bits_rm, bits_H, bits_H) -> (bits_fflags, bits_H)
val riscv_f16Mul = pure {lem: "softfloat_f16_mul"} : (bits_rm, bits_H, bits_H) -> (bits_fflags, bits_H)
val riscv_f16Div = pure {lem: "softfloat_f16_div"} : (bits_rm, bits_H, bits_H) -> (bits_fflags, bits_H)
val riscv_f32Add = pure {lem: "softfloat_f32_add"} : (bits_rm, bits_S, bits_S) -> (bits_fflags, bits_S)
val riscv_f32Sub = pure {lem: "softfloat_f32_sub"} : (bits_rm, bits_S, bits_S) -> (bits_fflags, bits_S)
val riscv_f32Mul = pure {lem: "softfloat_f32_mul"} : (bits_rm, bits_S, bits_S) -> (bits_fflags, bits_S)
val riscv_f32Div = pure {lem: "softfloat_f32_div"} : (bits_rm, bits_S, bits_S) -> (bits_fflags, bits_S)
val riscv_f64Add = pure {lem: "softfloat_f64_add"} : (bits_rm, bits_D, bits_D) -> (bits_fflags, bits_D)
val riscv_f64Sub = pure {lem: "softfloat_f64_sub"} : (bits_rm, bits_D, bits_D) -> (bits_fflags, bits_D)
val riscv_f64Mul = pure {lem: "softfloat_f64_mul"} : (bits_rm, bits_D, bits_D) -> (bits_fflags, bits_D)
val riscv_f64Div = pure {lem: "softfloat_f64_div"} : (bits_rm, bits_D, bits_D) -> (bits_fflags, bits_D)

// ***************************************************************
// MULTIPLY-ADD

val riscv_f16MulAdd = pure {lem: "softfloat_f16_muladd"} : (bits_rm, bits_H, bits_H, bits_H) -> (bits_fflags, bits_H)
val riscv_f32MulAdd = pure {lem: "softfloat_f32_muladd"} : (bits_rm, bits_S, bits_S, bits_S) -> (bits_fflags, bits_S)
val riscv_f64MulAdd = pure {lem: "softfloat_f64_muladd"} : (bits_rm, bits_D, bits_D, bits_D) -> (bits_fflags, bits_D)

// ***************************************************************
// SQUARE ROOT

val riscv_f16Sqrt = pure {lem: "softfloat_f16_sqrt"} : (bits_rm, bits_H) -> (bits_fflags, bits_H)
val riscv_f32Sqrt = pure {lem: "softfloat_f32_sqrt"} : (bits_rm, bits_S) -> (bits_fflags, bits_S)
val riscv_f64Sqrt = pure {lem: "softfloat_f64_sqrt"} : (bits_rm, bits_D) -> (bits_fflags, bits_D)

// ***************************************************************
// CONVERSIONS

val riscv_f16ToI32 = pure {lem: "softfloat_f16_to_i32"} : (bits_rm, bits_H) -> (bits_fflags, bits_W)
val riscv_f16ToUi32 = pure {lem: "softfloat_f16_to_ui32"} : (bits_rm, bits_H) -> (bits_fflags, bits_WU)
val riscv_i32ToF16 = pure {lem: "softfloat_i32_to_f16"} : (bits_rm, bits_W) -> (bits_fflags, bits_H)
val riscv_ui32ToF16 = pure {lem: "softfloat_ui32_to_f16"} : (bits_rm, bits_WU) -> (bits_fflags, bits_H)
val riscv_f16ToI64 = pure {lem: "softfloat_f16_to_i64"} : (bits_rm, bits_H) -> (bits_fflags, bits_L)
val riscv_f16ToUi64 = pure {lem: "softfloat_f16_to_ui64"} : (bits_rm, bits_H) -> (bits_fflags, bits_LU)
val riscv_i64ToF16 = pure {lem: "softfloat_i64_to_f16"} : (bits_rm, bits_L) -> (bits_fflags, bits_H)
val riscv_ui64ToF16 = pure {lem: "softfloat_ui64_to_f16"} : (bits_rm, bits_LU) -> (bits_fflags, bits_H)

val riscv_f32ToI32 = pure {lem: "softfloat_f32_to_i32"} : (bits_rm, bits_S) -> (bits_fflags, bits_W)
val riscv_f32ToUi32 = pure {lem: "softfloat_f32_to_ui32"} : (bits_rm, bits_S) -> (bits_fflags, bits_WU)
val riscv_i32ToF32 = pure {lem: "softfloat_i32_to_f32"} : (bits_rm, bits_W) -> (bits_fflags, bits_S)
val riscv_ui32ToF32 = pure {lem: "softfloat_ui32_to_f32"} : (bits_rm, bits_WU) -> (bits_fflags, bits_S)
val riscv_f32ToI64 = pure {lem: "softfloat_f32_to_i64"} : (bits_rm, bits_S) -> (bits_fflags, bits_L)
val riscv_f32ToUi64 = pure {lem: "softfloat_f32_to_ui64"} : (bits_rm, bits_S) -> (bits_fflags, bits_LU)
val riscv_i64ToF32 = pure {lem: "softfloat_i64_to_f32"} : (bits_rm, bits_L) -> (bits_fflags, bits_S)
val riscv_ui64ToF32 = pure {lem: "softfloat_ui64_to_f32"} : (bits_rm, bits_LU) -> (bits_fflags, bits_S)
val riscv_f64ToI32 = pure {lem: "softfloat_f64_to_i32"} : (bits_rm, bits_D) -> (bits_fflags, bits_W)
val riscv_f64ToUi32 = pure {lem: "softfloat_f64_to_ui32"} : (bits_rm, bits_D) -> (bits_fflags, bits_WU)
val riscv_i32ToF64 = pure {lem: "softfloat_i32_to_f64"} : (bits_rm, bits_W) -> (bits_fflags, bits_D)
val riscv_ui32ToF64 = pure {lem: "softfloat_ui32_to_f64"} : (bits_rm, bits_WU) -> (bits_fflags, bits_D)
val riscv_f64ToI64 = pure {lem: "softfloat_f64_to_i64"} : (bits_rm, bits_D) -> (bits_fflags, bits_L)
val riscv_f64ToUi64 = pure {lem: "softfloat_f64_to_ui64"} : (bits_rm, bits_D) -> (bits_fflags, bits_LU)
val riscv_i64ToF64 = pure {lem: "softfloat_i64_to_f64"} : (bits_rm, bits_L) -> (bits_fflags, bits_D)
val riscv_ui64ToF64 = pure {lem: "softfloat_ui64_to_f64"} : (bits_rm, bits_LU) -> (bits_fflags, bits_D)
val riscv_f16ToF32 = pure {lem: "softfloat_f16_to_f32"} : (bits_rm, bits_H) -> (bits_fflags, bits_S)
val riscv_f16ToF64 = pure {lem: "softfloat_f16_to_f64"} : (bits_rm, bits_H) -> (bits_fflags, bits_D)
val riscv_f32ToF64 = pure {lem: "softfloat_f32_to_f64"} : (bits_rm, bits_S) -> (bits_fflags, bits_D)
val riscv_f32ToF16 = pure {lem: "softfloat_f32_to_f16"} : (bits_rm, bits_S) -> (bits_fflags, bits_H)
val riscv_f64ToF16 = pure {lem: "softfloat_f64_to_f16"} : (bits_rm, bits_D) -> (bits_fflags, bits_H)
val riscv_f64ToF32 = pure {lem: "softfloat_f64_to_f32"} : (bits_rm, bits_D) -> (bits_fflags, bits_S)
val riscv_f32ToBF16 = pure {lem: "softfloat_f32_to_bf16"} : (bits_rm, bits_S) -> (bits_fflags, bits_BF16)

// ***************************************************************
// COMPARISONS

val riscv_f16Lt = pure {lem: "softfloat_f16_lt"} : (bits_H, bits_H) -> (bits_fflags, bool)
val riscv_f16Lt_quiet = pure {lem: "softfloat_f16_lt_quiet"} : (bits_H, bits_H) -> (bits_fflags, bool)
val riscv_f16Le = pure {lem: "softfloat_f16_le"} : (bits_H, bits_H) -> (bits_fflags, bool)
val riscv_f16Le_quiet = pure {lem: "softfloat_f16_le_quiet"} : (bits_H, bits_H) -> (bits_fflags, bool)
val riscv_f16Eq = pure {lem: "softfloat_f16_eq"} : (bits_H, bits_H) -> (bits_fflags, bool)
val riscv_f32Lt = pure {lem: "softfloat_f32_lt"} : (bits_S, bits_S) -> (bits_fflags, bool)
val riscv_f32Lt_quiet = pure {lem: "softfloat_f32_lt_quiet"} : (bits_S, bits_S) -> (bits_fflags, bool)
val riscv_f32Le = pure {lem: "softfloat_f32_le"} : (bits_S, bits_S) -> (bits_fflags, bool)
val riscv_f32Le_quiet = pure {lem: "softfloat_f32_le_quiet"} : (bits_S, bits_S) -> (bits_fflags, bool)
val riscv_f32Eq = pure {lem: "softfloat_f32_eq"} : (bits_S, bits_S) -> (bits_fflags, bool)
val riscv_f64Lt = pure {lem: "softfloat_f64_lt"} : (bits_D, bits_D) -> (bits_fflags, bool)
val riscv_f64Lt_quiet = pure {lem: "softfloat_f64_lt_quiet"} : (bits_D, bits_D) -> (bits_fflags, bool)
val riscv_f64Le = pure {lem: "softfloat_f64_le"} : (bits_D, bits_D) -> (bits_fflags, bool)
val riscv_f64Le_quiet = pure {lem: "softfloat_f64_le_quiet"} : (bits_D, bits_D) -> (bits_fflags, bool)
val riscv_f64Eq = pure {lem: "softfloat_f64_eq"} : (bits_D, bits_D) -> (bits_fflags, bool)
val riscv_f16roundToInt = pure {lem: "softfloat_f16_round_to_int"} : (bits_rm, bits_H, bool) -> (bits_fflags, bits_H)
val riscv_f32roundToInt = pure {lem: "softfloat_f32_round_to_int"} : (bits_rm, bits_S, bool) -> (bits_fflags, bits_S)
val riscv_f64roundToInt = pure {lem: "softfloat_f64_round_to_int"} : (bits_rm, bits_D, bool) -> (bits_fflags, bits_D)
