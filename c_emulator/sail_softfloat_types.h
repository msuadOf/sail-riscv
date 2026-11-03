#pragma once

#ifndef SOFTFLOAT_FAST_INT64
#error "The adapter and SoftFloat library must share SOFTFLOAT_FAST_INT64"
#endif
#ifndef THREAD_LOCAL
#error "The adapter and SoftFloat library must share the THREAD_LOCAL ABI"
#endif

extern "C" {
#include "softfloat.h"
}

// These are Sail sort equality, not IEEE numeric comparison.
bool eq_rounding_mode(uint_fast8_t, uint_fast8_t);
bool eq_float16(float16_t, float16_t);
bool eq_float32(float32_t, float32_t);
bool eq_float64(float64_t, float64_t);
bool eq_float128(float128_t, float128_t);
