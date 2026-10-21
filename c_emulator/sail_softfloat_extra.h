#pragma once

#include "sail.h"
#include "sail_softfloat_types.h"

// 数值接口；NaN 统一为正 quiet NaN，undefined 选择 +0。
#define SAIL_FP_EXTRA(N) \
  float##N##_t sail_undefined_float##N(unit); \
  float##N##_t sail_fp##N##_nan(unit); \
  float##N##_t sail_fp##N##_inf(unit); \
  float##N##_t sail_fp##N##_negative_inf(unit); \
  float##N##_t sail_fp##N##_negative_zero(unit); \
  float##N##_t sail_fp##N##_neg(float##N##_t); \
  bool sail_fp##N##_is_normal(float##N##_t); \
  bool sail_fp##N##_is_subnormal(float##N##_t); \
  bool sail_fp##N##_is_zero(float##N##_t); \
  bool sail_fp##N##_is_infinite(float##N##_t); \
  bool sail_fp##N##_is_positive(float##N##_t); \
  float##N##_t sail_fp##N##_rem(float##N##_t, float##N##_t); \
  float##N##_t sail_fp##N##_min(float##N##_t, float##N##_t); \
  float##N##_t sail_fp##N##_max(float##N##_t, float##N##_t)

SAIL_FP_EXTRA(16);
SAIL_FP_EXTRA(32);
SAIL_FP_EXTRA(64);
SAIL_FP_EXTRA(128);
#undef SAIL_FP_EXTRA

// fp128_zero 已在 P1 定义。
float16_t sail_fp16_zero(unit);
float32_t sail_fp32_zero(unit);
float64_t sail_fp64_zero(unit);

float16_t sail_fp128_to_fp16(uint_fast8_t, float128_t);
float32_t sail_fp128_to_fp32(uint_fast8_t, float128_t);
float64_t sail_fp128_to_fp64(uint_fast8_t, float128_t);
