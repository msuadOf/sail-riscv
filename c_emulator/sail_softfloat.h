#pragma once

#include "sail.h"
#include "sail_softfloat_types.h"

namespace sail_softfloat {
class Scope final {
public:
  explicit Scope(uint_fast8_t rm);
  ~Scope() noexcept;
  Scope(const Scope&) = delete;
  Scope& operator=(const Scope&) = delete;
private:
  uint_fast8_t old_rm_;
  uint_fast8_t old_tininess_;
  uint_fast8_t old_flags_;
};
}

uint_fast8_t sail_round_nearest_ties_to_even(unit);
uint_fast8_t sail_round_nearest_ties_to_away(unit);
uint_fast8_t sail_round_toward_positive(unit);
uint_fast8_t sail_round_toward_negative(unit);
uint_fast8_t sail_round_toward_zero(unit);

float128_t sail_fp128_zero(unit);

#define SAIL_FP_UNARY_TYPES(N) \
  float##N##_t sail_fp##N##_abs(float##N##_t); \
  bool sail_fp##N##_is_nan(float##N##_t); \
  bool sail_fp##N##_is_negative(float##N##_t); \
  float##N##_t sail_fp##N##_sqrt(uint_fast8_t, float##N##_t); \
  float##N##_t sail_fp##N##_round_to_integral(uint_fast8_t, float##N##_t); \
  bool sail_fp##N##_eq(float##N##_t, float##N##_t); \
  bool sail_fp##N##_lt(float##N##_t, float##N##_t); \
  bool sail_fp##N##_lteq(float##N##_t, float##N##_t); \
  bool sail_fp##N##_gt(float##N##_t, float##N##_t); \
  bool sail_fp##N##_gteq(float##N##_t, float##N##_t); \
  float##N##_t sail_fp##N##_add(uint_fast8_t, float##N##_t, float##N##_t); \
  float##N##_t sail_fp##N##_sub(uint_fast8_t, float##N##_t, float##N##_t); \
  float##N##_t sail_fp##N##_mul(uint_fast8_t, float##N##_t, float##N##_t); \
  float##N##_t sail_fp##N##_div(uint_fast8_t, float##N##_t, float##N##_t); \
  float##N##_t sail_fp##N##_fma(uint_fast8_t, float##N##_t, float##N##_t, float##N##_t); \
  float##N##_t sail_fp##N##_from_signed(uint_fast8_t, lbits); \
  float##N##_t sail_fp##N##_from_unsigned(uint_fast8_t, lbits); \
  uint64_t sail_fp##N##_to_signed32(uint_fast8_t, float##N##_t); \
  uint64_t sail_fp##N##_to_unsigned32(uint_fast8_t, float##N##_t); \
  uint64_t sail_fp##N##_to_signed64(uint_fast8_t, float##N##_t); \
  uint64_t sail_fp##N##_to_unsigned64(uint_fast8_t, float##N##_t); \
  uint64_t sail_fp##N##_to_signed16(uint_fast8_t, float##N##_t); \
  uint64_t sail_fp##N##_to_unsigned16(uint_fast8_t, float##N##_t); \
  void sail_fp##N##_to_signed128(lbits *, uint_fast8_t, float##N##_t); \
  void sail_fp##N##_to_unsigned128(lbits *, uint_fast8_t, float##N##_t)

SAIL_FP_UNARY_TYPES(16);
SAIL_FP_UNARY_TYPES(32);
SAIL_FP_UNARY_TYPES(64);
SAIL_FP_UNARY_TYPES(128);
#undef SAIL_FP_UNARY_TYPES

float16_t sail_fp16_from_ieee(uint64_t);
float32_t sail_fp32_from_ieee(uint64_t);
float64_t sail_fp64_from_ieee(uint64_t);
float128_t sail_fp128_from_ieee(lbits);
uint64_t sail_fp16_to_ieee(float16_t);
uint64_t sail_fp32_to_ieee(float32_t);
uint64_t sail_fp64_to_ieee(float64_t);
void sail_fp128_to_ieee(lbits *, float128_t);
uint64_t sail_fp32_to_bf16(uint_fast8_t, float32_t);

#define SAIL_FP_CONVERT(A, B) float##B##_t sail_fp##A##_to_fp##B(uint_fast8_t, float##A##_t)
SAIL_FP_CONVERT(16, 32);
SAIL_FP_CONVERT(16, 64);
SAIL_FP_CONVERT(16, 128);
SAIL_FP_CONVERT(32, 16);
SAIL_FP_CONVERT(32, 64);
SAIL_FP_CONVERT(32, 128);
SAIL_FP_CONVERT(64, 16);
SAIL_FP_CONVERT(64, 32);
SAIL_FP_CONVERT(64, 128);
#undef SAIL_FP_CONVERT

#ifdef SAIL_SOFTFLOAT_ENABLE_EXTRA
#include "sail_softfloat_extra.h"
#endif
