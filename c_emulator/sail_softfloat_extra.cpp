#include "sail_softfloat_extra.h"
#include "sail_softfloat.h"

#include <cstdint>

namespace {

// 位分类使用整数，避免宿主浮点类型、NaN payload 或环境副作用。
template <typename F> struct Format;
#define SMALL_FORMAT(N, SIGN, EXP, FRAC, QUIET) \
  template <> struct Format<float##N##_t> { \
    static constexpr uint64_t sign = SIGN, exponent = EXP, fraction = FRAC, quiet = QUIET; \
    static uint64_t high(float##N##_t x) { return x.v; } \
    static uint64_t low(float##N##_t) { return 0; } \
    static float##N##_t make(uint64_t high, uint64_t = 0) { \
      return float##N##_t{static_cast<uint##N##_t>(high)}; \
    } \
    static bool less(float##N##_t a, float##N##_t b) { return f##N##_lt_quiet(a, b); } \
  }
SMALL_FORMAT(16, UINT64_C(0x8000), UINT64_C(0x7c00), UINT64_C(0x03ff), UINT64_C(0x0200));
SMALL_FORMAT(32, UINT64_C(0x80000000), UINT64_C(0x7f800000), UINT64_C(0x007fffff), UINT64_C(0x00400000));
SMALL_FORMAT(64, UINT64_C(0x8000000000000000), UINT64_C(0x7ff0000000000000), UINT64_C(0x000fffffffffffff), UINT64_C(0x0008000000000000));
#undef SMALL_FORMAT

template <> struct Format<float128_t> {
  static constexpr uint64_t sign = UINT64_C(0x8000000000000000);
  static constexpr uint64_t exponent = UINT64_C(0x7fff000000000000);
  static constexpr uint64_t fraction = UINT64_C(0x0000ffffffffffff);
  static constexpr uint64_t quiet = UINT64_C(0x0000800000000000);
  static uint64_t high(float128_t x) { return x.v[1]; }
  static uint64_t low(float128_t x) { return x.v[0]; }
  static float128_t make(uint64_t high, uint64_t low = 0) { return float128_t{{low, high}}; }
  static bool less(float128_t a, float128_t b) { return f128_lt_quiet(a, b); }
};

template <typename F> bool has_fraction(F x) {
  return (Format<F>::high(x) & Format<F>::fraction) || Format<F>::low(x);
}
template <typename F> bool is_nan(F x) {
  return (Format<F>::high(x) & Format<F>::exponent) == Format<F>::exponent && has_fraction(x);
}
template <typename F> bool is_zero(F x) {
  return !(Format<F>::high(x) & ~Format<F>::sign) && !Format<F>::low(x);
}
template <typename F> F nan_value() {
  return Format<F>::make(Format<F>::exponent | Format<F>::quiet);
}
template <typename F> F canonical(F x) { return is_nan(x) ? nan_value<F>() : x; }

template <typename F> F minmax(F a, F b, bool maximum) {
  sail_softfloat::Scope scope(softfloat_round_near_even);
  if (is_nan(a)) return canonical(b);
  if (is_nan(b)) return a;
  if (is_zero(a) && is_zero(b)) {
    // 异号零的允许结果中，min 选择 -0，max 选择 +0。
    const uint64_t sign = maximum ? (Format<F>::high(a) & Format<F>::high(b))
                                  : (Format<F>::high(a) | Format<F>::high(b));
    return Format<F>::make(sign & Format<F>::sign);
  }
  return maximum ? (Format<F>::less(a, b) ? b : a)
                 : (Format<F>::less(b, a) ? b : a);
}

} // namespace

#define EXTRA_FORMAT(N) \
  float##N##_t sail_undefined_float##N(unit) { return Format<float##N##_t>::make(0); } \
  float##N##_t sail_fp##N##_nan(unit) { return nan_value<float##N##_t>(); } \
  float##N##_t sail_fp##N##_inf(unit) { return Format<float##N##_t>::make(Format<float##N##_t>::exponent); } \
  float##N##_t sail_fp##N##_negative_inf(unit) { \
    return Format<float##N##_t>::make(Format<float##N##_t>::exponent | Format<float##N##_t>::sign); \
  } \
  float##N##_t sail_fp##N##_negative_zero(unit) { return Format<float##N##_t>::make(Format<float##N##_t>::sign); } \
  float##N##_t sail_fp##N##_neg(float##N##_t x) { \
    return is_nan(x) ? nan_value<float##N##_t>() \
                    : Format<float##N##_t>::make(Format<float##N##_t>::high(x) ^ Format<float##N##_t>::sign, Format<float##N##_t>::low(x)); \
  } \
  bool sail_fp##N##_is_normal(float##N##_t x) { \
    const uint64_t exponent = Format<float##N##_t>::high(x) & Format<float##N##_t>::exponent; \
    return exponent && exponent != Format<float##N##_t>::exponent; \
  } \
  bool sail_fp##N##_is_subnormal(float##N##_t x) { \
    return !(Format<float##N##_t>::high(x) & Format<float##N##_t>::exponent) && has_fraction(x); \
  } \
  bool sail_fp##N##_is_zero(float##N##_t x) { return is_zero(x); } \
  bool sail_fp##N##_is_infinite(float##N##_t x) { \
    return (Format<float##N##_t>::high(x) & Format<float##N##_t>::exponent) == Format<float##N##_t>::exponent && !has_fraction(x); \
  } \
  bool sail_fp##N##_is_positive(float##N##_t x) { return !is_nan(x) && !(Format<float##N##_t>::high(x) & Format<float##N##_t>::sign); } \
  float##N##_t sail_fp##N##_rem(float##N##_t a, float##N##_t b) { \
    sail_softfloat::Scope scope(softfloat_round_near_even); return canonical(f##N##_rem(a, b)); \
  } \
  float##N##_t sail_fp##N##_min(float##N##_t a, float##N##_t b) { return minmax(a, b, false); } \
  float##N##_t sail_fp##N##_max(float##N##_t a, float##N##_t b) { return minmax(a, b, true); }
EXTRA_FORMAT(16)
EXTRA_FORMAT(32)
EXTRA_FORMAT(64)
EXTRA_FORMAT(128)
#undef EXTRA_FORMAT

float16_t sail_fp16_zero(unit) { return float16_t{0}; }
float32_t sail_fp32_zero(unit) { return float32_t{0}; }
float64_t sail_fp64_zero(unit) { return float64_t{0}; }

#define NARROW(N) \
  float##N##_t sail_fp128_to_fp##N(uint_fast8_t rm, float128_t x) { \
    sail_softfloat::Scope scope(rm); return canonical(f128_to_f##N(x)); \
  }
NARROW(16)
NARROW(32)
NARROW(64)
#undef NARROW
