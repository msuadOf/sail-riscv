#include "sail_softfloat_wide.h"

#include <array>
#include <cstddef>
#include <cstdint>
#include <cstdlib>

#include "sail_softfloat.h"

extern "C" {
#include "platform.h"
#include "internals.h"
#include "softfloat.h"
}

namespace sail_softfloat::wide {
namespace {

struct LocalInteger {
  mpz_t value;
  LocalInteger() { mpz_init(value); }
  ~LocalInteger() { mpz_clear(value); }
  LocalInteger(const LocalInteger &) = delete;
  LocalInteger &operator=(const LocalInteger &) = delete;
};

struct Format {
  unsigned precision;
  unsigned exponent_bits;
  unsigned guard_bits;
  int bias;
};

constexpr Format f16_format{11, 5, 4, 15};
constexpr Format f32_format{24, 8, 7, 127};
constexpr Format f64_format{53, 11, 10, 1023};
constexpr Format f128_format{113, 15, 64, 16383};

using Words = std::array<uint64_t, 3>;

Words export_words(const mpz_t value) {
  Words words{};
  size_t count = 0;
  if (mpz_sgn(value) < 0 ||
      (mpz_sgn(value) != 0 && mpz_sizeinbase(value, 2) > 192))
    std::abort();
  mpz_export(words.data(), &count, -1, sizeof(uint64_t), 0, 0, value);
  return words;
}

void import_words(mpz_t result, const uint64_t *words, size_t count) {
  mpz_import(result, count, -1, sizeof(uint64_t), 0, 0, words);
}

struct PackInput {
  bool sign;
  int exponent;
  Words significand;
};

PackInput prepare_pack(lbits raw, bool signed_input, Format format) {
  PackInput result{};
  if (raw.len == 0) return result;

  LocalInteger magnitude;
  mpz_fdiv_r_2exp(magnitude.value, *raw.bits, raw.len);
  result.sign = signed_input && mpz_tstbit(magnitude.value, raw.len - 1);
  if (result.sign) {
    mpz_neg(magnitude.value, magnitude.value);
    mpz_fdiv_r_2exp(magnitude.value, magnitude.value, raw.len);
  }
  if (mpz_sgn(magnitude.value) == 0) return result;

  const size_t length = mpz_sizeinbase(magnitude.value, 2);
  const size_t kept = format.precision + format.guard_bits;
  LocalInteger rounded_input;
  if (length - 1 > static_cast<size_t>(format.bias)) {
    // roundPack handles all rounding modes' overflow choices from this sentinel.
    result.exponent = format.bias * 2;
    mpz_setbit(rounded_input.value, kept - 1);
  } else {
    result.exponent = static_cast<int>(length - 1) + format.bias - 1;
    if (length <= kept) {
      mpz_mul_2exp(rounded_input.value, magnitude.value, kept - length);
    } else {
      const size_t discarded = length - kept;
      mpz_fdiv_q_2exp(rounded_input.value, magnitude.value, discarded);
      if (!mpz_divisible_2exp_p(magnitude.value, discarded))
        mpz_setbit(rounded_input.value, 0);
    }
  }
  result.significand = export_words(rounded_input.value);
  return result;
}

bool unpack_rounded(mpz_t integer, const uint64_t *words, size_t count,
                    Format format, unsigned width, bool signed_output) {
  LocalInteger bits;
  import_words(bits.value, words, count);
  const unsigned fp_width = format.precision + format.exponent_bits;
  const bool sign = mpz_tstbit(bits.value, fp_width - 1);
  LocalInteger exponent_bits;
  mpz_fdiv_q_2exp(exponent_bits.value, bits.value, format.precision - 1);
  const unsigned exponent = mpz_get_ui(exponent_bits.value) &
                            ((1u << format.exponent_bits) - 1);
  if (exponent == ((1u << format.exponent_bits) - 1)) return false;

  LocalInteger magnitude;
  mpz_fdiv_r_2exp(magnitude.value, bits.value, format.precision - 1);
  if (exponent == 0 && mpz_sgn(magnitude.value) == 0) {
    mpz_set_ui(integer, 0);
    return true;
  }
  // A nonzero result of roundToInt is a normal, exactly integral FP value.
  if (exponent == 0) return false;
  mpz_setbit(magnitude.value, format.precision - 1);
  const int shift = static_cast<int>(exponent) - format.bias -
                    static_cast<int>(format.precision - 1);
  if (shift >= 0) {
    mpz_mul_2exp(magnitude.value, magnitude.value, shift);
  } else {
    const unsigned right_shift = static_cast<unsigned>(-shift);
    if (!mpz_divisible_2exp_p(magnitude.value, right_shift)) return false;
    mpz_fdiv_q_2exp(magnitude.value, magnitude.value, right_shift);
  }
  if (sign) mpz_neg(magnitude.value, magnitude.value);

  LocalInteger bound;
  mpz_set_ui(bound.value, 1);
  mpz_mul_2exp(bound.value, bound.value, width - (signed_output ? 1 : 0));
  if (mpz_cmp(magnitude.value, bound.value) >= 0) return false;
  if (signed_output) {
    mpz_neg(bound.value, bound.value);
    if (mpz_cmp(magnitude.value, bound.value) < 0) return false;
  } else if (mpz_sgn(magnitude.value) < 0) {
    return false;
  }
  mpz_fdiv_r_2exp(integer, magnitude.value, width);
  return true;
}

} // namespace

#define DEFINE_FP_CONVERSIONS(N, FORMAT)                                          \
  float##N##_t from_signed##N(uint_fast8_t rm, lbits raw) {                      \
    const PackInput p = prepare_pack(raw, true, FORMAT);                          \
    Scope scope(rm);                                                              \
    return softfloat_roundPackToF##N(p.sign, p.exponent, p.significand[0]);       \
  }                                                                              \
  float##N##_t from_unsigned##N(uint_fast8_t rm, lbits raw) {                    \
    const PackInput p = prepare_pack(raw, false, FORMAT);                         \
    Scope scope(rm);                                                              \
    return softfloat_roundPackToF##N(p.sign, p.exponent, p.significand[0]);       \
  }

DEFINE_FP_CONVERSIONS(16, f16_format)
DEFINE_FP_CONVERSIONS(32, f32_format)
DEFINE_FP_CONVERSIONS(64, f64_format)
#undef DEFINE_FP_CONVERSIONS

float128_t from_signed128(uint_fast8_t rm, lbits raw) {
  const PackInput p = prepare_pack(raw, true, f128_format);
  Scope scope(rm);
  return softfloat_roundPackToF128(p.sign, p.exponent, p.significand[2],
                                  p.significand[1], p.significand[0]);
}

float128_t from_unsigned128(uint_fast8_t rm, lbits raw) {
  const PackInput p = prepare_pack(raw, false, f128_format);
  Scope scope(rm);
  return softfloat_roundPackToF128(p.sign, p.exponent, p.significand[2],
                                  p.significand[1], p.significand[0]);
}

// Classify before roundToInt so that NaNs, infinities and their payloads all
// return the same deterministic out-of-domain value.
template <typename Float>
bool rounded_integer(mpz_t result, uint_fast8_t rm, Float value,
                     unsigned width, bool signed_output);

#define DEFINE_ROUNDED_INTEGER(N, FORMAT, RAW_TYPE)                               \
  template <>                                                                    \
  bool rounded_integer<float##N##_t>(mpz_t result, uint_fast8_t rm,             \
                                      float##N##_t value, unsigned width,         \
                                      bool signed_output) {                       \
    const RAW_TYPE exponent =                                                   \
        (value.v >> (FORMAT.precision - 1)) &                                    \
        ((RAW_TYPE(1) << FORMAT.exponent_bits) - 1);                              \
    if (exponent == ((RAW_TYPE(1) << FORMAT.exponent_bits) - 1)) return false;    \
    Scope scope(rm);                                                              \
    const float##N##_t rounded = f##N##_roundToInt(value, rm, false);            \
    const uint64_t words[] = {rounded.v};                                         \
    return unpack_rounded(result, words, 1, FORMAT, width, signed_output);       \
  }

DEFINE_ROUNDED_INTEGER(16, f16_format, uint16_t)
DEFINE_ROUNDED_INTEGER(32, f32_format, uint32_t)
DEFINE_ROUNDED_INTEGER(64, f64_format, uint64_t)
#undef DEFINE_ROUNDED_INTEGER

template <>
bool rounded_integer<float128_t>(mpz_t result, uint_fast8_t rm,
                                 float128_t value, unsigned width,
                                 bool signed_output) {
  const unsigned exponent = (value.v[1] >> 48) & 0x7fff;
  if (exponent == 0x7fff) return false;
  Scope scope(rm);
  const float128_t rounded = f128_roundToInt(value, rm, false);
  return unpack_rounded(result, rounded.v, 2, f128_format, width, signed_output);
}

template <typename Float>
uint64_t small_result(uint_fast8_t rm, Float value, unsigned width,
                      bool signed_output) {
  LocalInteger result;
  if (!rounded_integer(result.value, rm, value, width, signed_output)) return 0;
  return export_words(result.value)[0];
}

template <typename Float>
void wide_result(lbits *result, uint_fast8_t rm, Float value,
                 bool signed_output) {
  LocalInteger integer;
  if (!rounded_integer(integer.value, rm, value, 128, signed_output))
    mpz_set_ui(integer.value, 0);
  result->len = 128;
  mpz_set(*result->bits, integer.value);
}

#define DEFINE_SMALL_OUTPUT(N, W)                                                \
  uint64_t to_signed##W(uint_fast8_t rm, float##N##_t value) {                   \
    return small_result(rm, value, W, true);                                      \
  }                                                                              \
  uint64_t to_unsigned##W(uint_fast8_t rm, float##N##_t value) {                 \
    return small_result(rm, value, W, false);                                     \
  }

#define DEFINE_WIDE_OUTPUT(N)                                                     \
  void to_signed128(lbits *result, uint_fast8_t rm, float##N##_t value) {        \
    wide_result(result, rm, value, true);                                         \
  }                                                                              \
  void to_unsigned128(lbits *result, uint_fast8_t rm, float##N##_t value) {      \
    wide_result(result, rm, value, false);                                        \
  }

#define DEFINE_ALL_OUTPUT(N)                                                      \
  DEFINE_SMALL_OUTPUT(N, 16)                                                      \
  DEFINE_SMALL_OUTPUT(N, 32)                                                      \
  DEFINE_SMALL_OUTPUT(N, 64)                                                      \
  DEFINE_WIDE_OUTPUT(N)

DEFINE_ALL_OUTPUT(16)
DEFINE_ALL_OUTPUT(32)
DEFINE_ALL_OUTPUT(64)
DEFINE_ALL_OUTPUT(128)
#undef DEFINE_ALL_OUTPUT
#undef DEFINE_WIDE_OUTPUT
#undef DEFINE_SMALL_OUTPUT

float128_t from_ieee128(lbits raw) {
  if (raw.len != 128) std::abort();
  LocalInteger bits;
  mpz_fdiv_r_2exp(bits.value, *raw.bits, 128);
  const Words words = export_words(bits.value);
  return float128_t{{words[0], words[1]}};
}

void to_ieee128(lbits *result, float128_t value) {
  uint64_t words[2] = {value.v[0], value.v[1]};
  if (((words[1] >> 48) & 0x7fff) == 0x7fff &&
      ((words[1] & UINT64_C(0x0000ffffffffffff)) != 0 || words[0] != 0)) {
    words[0] = 0;
    words[1] = UINT64_C(0x7fff800000000000);
  }
  result->len = 128;
  import_words(*result->bits, words, 2);
}

} // namespace sail_softfloat::wide
