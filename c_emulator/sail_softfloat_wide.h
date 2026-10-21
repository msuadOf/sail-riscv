#pragma once

#include <cstdint>
#include "sail.h"
#include "sail_softfloat_types.h"

// Internal numeric hooks. The public Sail externs live in sail_softfloat.cpp.
namespace sail_softfloat::wide {

float16_t from_signed16(uint_fast8_t rm, lbits raw);
float32_t from_signed32(uint_fast8_t rm, lbits raw);
float64_t from_signed64(uint_fast8_t rm, lbits raw);
float128_t from_signed128(uint_fast8_t rm, lbits raw);
float16_t from_unsigned16(uint_fast8_t rm, lbits raw);
float32_t from_unsigned32(uint_fast8_t rm, lbits raw);
float64_t from_unsigned64(uint_fast8_t rm, lbits raw);
float128_t from_unsigned128(uint_fast8_t rm, lbits raw);

#define SAIL_WIDE_TO_DECL(N, W) \
  uint64_t to_signed##W(uint_fast8_t rm, float##N##_t value); \
  uint64_t to_unsigned##W(uint_fast8_t rm, float##N##_t value)
#define SAIL_WIDE_TO_128_DECL(N) \
  void to_signed128(lbits *result, uint_fast8_t rm, float##N##_t value); \
  void to_unsigned128(lbits *result, uint_fast8_t rm, float##N##_t value)
#define SAIL_WIDE_TO_ALL_DECL(N) \
  SAIL_WIDE_TO_DECL(N, 16); \
  SAIL_WIDE_TO_DECL(N, 32); \
  SAIL_WIDE_TO_DECL(N, 64); \
  SAIL_WIDE_TO_128_DECL(N)

SAIL_WIDE_TO_ALL_DECL(16);
SAIL_WIDE_TO_ALL_DECL(32);
SAIL_WIDE_TO_ALL_DECL(64);
SAIL_WIDE_TO_ALL_DECL(128);

#undef SAIL_WIDE_TO_ALL_DECL
#undef SAIL_WIDE_TO_128_DECL
#undef SAIL_WIDE_TO_DECL

float128_t from_ieee128(lbits raw);
void to_ieee128(lbits *result, float128_t value);

} // namespace sail_softfloat::wide
