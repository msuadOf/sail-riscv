#include "sail_softfloat.h"

#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <limits>

#ifdef SAIL_SOFTFLOAT_ENABLE_WIDE
#include "sail_softfloat_wide.h"
#endif

static_assert(std::numeric_limits<unsigned long>::digits >= 64,
              "The Sail lbits import requires 64-bit GMP limbs on this host");

namespace {

void check_rm(uint_fast8_t rm) {
  if (rm > softfloat_round_near_maxMag) std::abort();
}

uint64_t checked_integer(lbits b) {
  if ((b.len != 32 && b.len != 64) || b.bits == nullptr) std::abort();
  return mpz_get_ui(*b.bits);
}

int32_t signed32(uint64_t bits) {
  uint32_t u = static_cast<uint32_t>(bits);
  int32_t s;
  std::memcpy(&s, &u, sizeof(s));
  return s;
}

int64_t signed64(uint64_t bits) {
  int64_t s;
  std::memcpy(&s, &bits, sizeof(s));
  return s;
}

bool nan16(float16_t x) { return (x.v & 0x7c00u) == 0x7c00u && (x.v & 0x03ffu); }
bool nan32(float32_t x) { return (x.v & 0x7f800000u) == 0x7f800000u && (x.v & 0x007fffffu); }
bool nan64(float64_t x) { return (x.v & UINT64_C(0x7ff0000000000000)) == UINT64_C(0x7ff0000000000000) && (x.v & UINT64_C(0x000fffffffffffff)); }
bool nan128(float128_t x) { return (x.v[1] & UINT64_C(0x7fff000000000000)) == UINT64_C(0x7fff000000000000) && ((x.v[1] & UINT64_C(0x0000ffffffffffff)) || x.v[0]); }

float16_t canonical(float16_t x) { if (nan16(x)) x.v = 0x7e00u; return x; }
float32_t canonical(float32_t x) { if (nan32(x)) x.v = 0x7fc00000u; return x; }
float64_t canonical(float64_t x) { if (nan64(x)) x.v = UINT64_C(0x7ff8000000000000); return x; }
float128_t canonical(float128_t x) {
  if (nan128(x)) { x.v[0] = 0; x.v[1] = UINT64_C(0x7fff800000000000); }
  return x;
}

} // namespace

namespace sail_softfloat {
Scope::Scope(uint_fast8_t rm)
    : old_rm_(softfloat_roundingMode), old_tininess_(softfloat_detectTininess),
      old_flags_(softfloat_exceptionFlags) {
  check_rm(rm);
  softfloat_roundingMode = rm;
  softfloat_detectTininess = softfloat_tininess_afterRounding;
  softfloat_exceptionFlags = 0;
}

Scope::~Scope() noexcept {
  softfloat_roundingMode = old_rm_;
  softfloat_detectTininess = old_tininess_;
  softfloat_exceptionFlags = old_flags_;
}
} // namespace sail_softfloat

bool eq_rounding_mode(uint_fast8_t a, uint_fast8_t b) { return a == b; }
#define SORT_EQUAL(N, NAN, EQUAL) \
  bool eq_float##N(float##N##_t a, float##N##_t b) { \
    if (NAN(a) || NAN(b)) return NAN(a) && NAN(b); \
    return EQUAL; \
  }
SORT_EQUAL(16, nan16, a.v == b.v)
SORT_EQUAL(32, nan32, a.v == b.v)
SORT_EQUAL(64, nan64, a.v == b.v)
SORT_EQUAL(128, nan128, a.v[0] == b.v[0] && a.v[1] == b.v[1])
#undef SORT_EQUAL

uint_fast8_t sail_round_nearest_ties_to_even(unit) { return softfloat_round_near_even; }
uint_fast8_t sail_round_nearest_ties_to_away(unit) { return softfloat_round_near_maxMag; }
uint_fast8_t sail_round_toward_positive(unit) { return softfloat_round_max; }
uint_fast8_t sail_round_toward_negative(unit) { return softfloat_round_min; }
uint_fast8_t sail_round_toward_zero(unit) { return softfloat_round_minMag; }

float128_t sail_fp128_zero(unit) { return float128_t{{0, 0}}; }

float16_t sail_fp16_from_ieee(uint64_t b) { return float16_t{static_cast<uint16_t>(b)}; }
float32_t sail_fp32_from_ieee(uint64_t b) { return float32_t{static_cast<uint32_t>(b)}; }
float64_t sail_fp64_from_ieee(uint64_t b) { return float64_t{b}; }
float128_t sail_fp128_from_ieee(lbits b) {
#ifdef SAIL_SOFTFLOAT_ENABLE_WIDE
  return sail_softfloat::wide::from_ieee128(b);
#else
  if (b.len != 128 || b.bits == nullptr) std::abort();
  float128_t x{{mpz_get_ui(*b.bits), 0}};
  mpz_t high;
  mpz_init(high);
  mpz_fdiv_q_2exp(high, *b.bits, 64);
  x.v[1] = mpz_get_ui(high);
  mpz_clear(high);
  return x;
#endif
}
uint64_t sail_fp16_to_ieee(float16_t x) { return canonical(x).v; }
uint64_t sail_fp32_to_ieee(float32_t x) { return canonical(x).v; }
uint64_t sail_fp64_to_ieee(float64_t x) { return canonical(x).v; }
#ifdef SAIL_SOFTFLOAT_ENABLE_WIDE
void sail_fp128_to_ieee(lbits *result, float128_t x) {
  sail_softfloat::wide::to_ieee128(result, x);
}
#endif

#define SIMPLE_FORMAT(N, SIGN, NAN) \
  float##N##_t sail_fp##N##_abs(float##N##_t x) { x.v &= ~SIGN; return canonical(x); } \
  bool sail_fp##N##_is_nan(float##N##_t x) { return NAN(x); } \
  bool sail_fp##N##_is_negative(float##N##_t x) { return !NAN(x) && (x.v & SIGN); }
SIMPLE_FORMAT(16, UINT16_C(0x8000), nan16)
SIMPLE_FORMAT(32, UINT32_C(0x80000000), nan32)
SIMPLE_FORMAT(64, UINT64_C(0x8000000000000000), nan64)
#undef SIMPLE_FORMAT
float128_t sail_fp128_abs(float128_t x) { x.v[1] &= UINT64_C(0x7fffffffffffffff); return canonical(x); }
bool sail_fp128_is_nan(float128_t x) { return nan128(x); }
bool sail_fp128_is_negative(float128_t x) { return !nan128(x) && (x.v[1] >> 63); }

#ifdef SAIL_SOFTFLOAT_ENABLE_WIDE
#define SAIL_WIDE_SIGNED_FALLBACK(N, RM, B) \
  if ((B).len != 32 && (B).len != 64) return sail_softfloat::wide::from_signed##N((RM), (B));
#define SAIL_WIDE_UNSIGNED_FALLBACK(N, RM, B) \
  if ((B).len != 32 && (B).len != 64) return sail_softfloat::wide::from_unsigned##N((RM), (B));
#else
#define SAIL_WIDE_SIGNED_FALLBACK(N, RM, B)
#define SAIL_WIDE_UNSIGNED_FALLBACK(N, RM, B)
#endif

#define NUMERIC_FORMAT(N) \
  float##N##_t sail_fp##N##_sqrt(uint_fast8_t rm, float##N##_t x) { sail_softfloat::Scope scope(rm); return canonical(f##N##_sqrt(x)); } \
  float##N##_t sail_fp##N##_round_to_integral(uint_fast8_t rm, float##N##_t x) { sail_softfloat::Scope scope(rm); return canonical(f##N##_roundToInt(x, rm, false)); } \
  bool sail_fp##N##_eq(float##N##_t a, float##N##_t b) { sail_softfloat::Scope scope(0); return f##N##_eq(a,b); } \
  bool sail_fp##N##_lt(float##N##_t a, float##N##_t b) { sail_softfloat::Scope scope(0); return f##N##_lt_quiet(a,b); } \
  bool sail_fp##N##_lteq(float##N##_t a, float##N##_t b) { sail_softfloat::Scope scope(0); return f##N##_le_quiet(a,b); } \
  bool sail_fp##N##_gt(float##N##_t a, float##N##_t b) { sail_softfloat::Scope scope(0); return f##N##_lt_quiet(b,a); } \
  bool sail_fp##N##_gteq(float##N##_t a, float##N##_t b) { sail_softfloat::Scope scope(0); return f##N##_le_quiet(b,a); } \
  float##N##_t sail_fp##N##_add(uint_fast8_t rm, float##N##_t a, float##N##_t b) { sail_softfloat::Scope scope(rm); return canonical(f##N##_add(a,b)); } \
  float##N##_t sail_fp##N##_sub(uint_fast8_t rm, float##N##_t a, float##N##_t b) { sail_softfloat::Scope scope(rm); return canonical(f##N##_sub(a,b)); } \
  float##N##_t sail_fp##N##_mul(uint_fast8_t rm, float##N##_t a, float##N##_t b) { sail_softfloat::Scope scope(rm); return canonical(f##N##_mul(a,b)); } \
  float##N##_t sail_fp##N##_div(uint_fast8_t rm, float##N##_t a, float##N##_t b) { sail_softfloat::Scope scope(rm); return canonical(f##N##_div(a,b)); } \
  float##N##_t sail_fp##N##_fma(uint_fast8_t rm, float##N##_t a, float##N##_t b, float##N##_t c) { sail_softfloat::Scope scope(rm); return canonical(f##N##_mulAdd(a,b,c)); } \
  float##N##_t sail_fp##N##_from_signed(uint_fast8_t rm, lbits b) { \
    SAIL_WIDE_SIGNED_FALLBACK(N, rm, b) \
    const uint64_t u = checked_integer(b); sail_softfloat::Scope scope(rm); \
    return canonical(b.len == 32 ? i32_to_f##N(signed32(u)) : i64_to_f##N(signed64(u))); \
  } \
  float##N##_t sail_fp##N##_from_unsigned(uint_fast8_t rm, lbits b) { \
    SAIL_WIDE_UNSIGNED_FALLBACK(N, rm, b) \
    const uint64_t u = checked_integer(b); sail_softfloat::Scope scope(rm); \
    return canonical(b.len == 32 ? ui32_to_f##N(static_cast<uint32_t>(u)) : ui64_to_f##N(u)); \
  } \
  uint64_t sail_fp##N##_to_signed32(uint_fast8_t rm, float##N##_t x) { sail_softfloat::Scope scope(rm); return static_cast<uint32_t>(f##N##_to_i32(canonical(x), rm, false)); } \
  uint64_t sail_fp##N##_to_unsigned32(uint_fast8_t rm, float##N##_t x) { sail_softfloat::Scope scope(rm); return static_cast<uint32_t>(f##N##_to_ui32(canonical(x), rm, false)); } \
  uint64_t sail_fp##N##_to_signed64(uint_fast8_t rm, float##N##_t x) { sail_softfloat::Scope scope(rm); return static_cast<uint64_t>(f##N##_to_i64(canonical(x), rm, false)); } \
  uint64_t sail_fp##N##_to_unsigned64(uint_fast8_t rm, float##N##_t x) { sail_softfloat::Scope scope(rm); return static_cast<uint64_t>(f##N##_to_ui64(canonical(x), rm, false)); }
NUMERIC_FORMAT(16)
NUMERIC_FORMAT(32)
NUMERIC_FORMAT(64)
NUMERIC_FORMAT(128)
#undef NUMERIC_FORMAT
#undef SAIL_WIDE_SIGNED_FALLBACK
#undef SAIL_WIDE_UNSIGNED_FALLBACK

#ifdef SAIL_SOFTFLOAT_ENABLE_WIDE
#define WIDE_INTEGER_OUTPUTS(N) \
  uint64_t sail_fp##N##_to_signed16(uint_fast8_t rm, float##N##_t x) { \
    return sail_softfloat::wide::to_signed16(rm, x); \
  } \
  uint64_t sail_fp##N##_to_unsigned16(uint_fast8_t rm, float##N##_t x) { \
    return sail_softfloat::wide::to_unsigned16(rm, x); \
  } \
  void sail_fp##N##_to_signed128(lbits *result, uint_fast8_t rm, float##N##_t x) { \
    sail_softfloat::wide::to_signed128(result, rm, x); \
  } \
  void sail_fp##N##_to_unsigned128(lbits *result, uint_fast8_t rm, float##N##_t x) { \
    sail_softfloat::wide::to_unsigned128(result, rm, x); \
  }
WIDE_INTEGER_OUTPUTS(16)
WIDE_INTEGER_OUTPUTS(32)
WIDE_INTEGER_OUTPUTS(64)
WIDE_INTEGER_OUTPUTS(128)
#undef WIDE_INTEGER_OUTPUTS
#endif

#define CONVERT(A, B) \
  float##B##_t sail_fp##A##_to_fp##B(uint_fast8_t rm, float##A##_t x) { \
    sail_softfloat::Scope scope(rm); return canonical(f##A##_to_f##B(x)); \
  }
CONVERT(16, 32)
CONVERT(16, 64)
CONVERT(16, 128)
CONVERT(32, 16)
CONVERT(32, 64)
CONVERT(32, 128)
CONVERT(64, 16)
CONVERT(64, 32)
CONVERT(64, 128)
#undef CONVERT

uint64_t sail_fp32_to_bf16(uint_fast8_t rm, float32_t x) {
  if (nan32(x)) return 0x7fc0u;
  sail_softfloat::Scope scope(rm);
  return f32_to_bf16(x).v;
}
