#!/usr/bin/env python3
"""Emit reproducible f64 wrapper cases from the independent SoftFloat oracle."""

import json
import math
import random
import struct
import subprocess
import sys


oracle = sys.argv[1]


def case(function, arguments, op, fmt="f64", rm=None, a=None, b=None, c=None, dst=None, exact=None):
    command = [oracle, "--op", op, "--fmt", fmt]
    for option, value in (("rm", rm), ("a", a), ("b", b), ("c", c), ("dst", dst), ("exact", exact)):
        if value is not None:
            command += [f"--{option}", str(value)]
    result = json.loads(subprocess.check_output(command, text=True))
    value = result["result_bits"]
    width = {"f16": 16, "f32": 32, "f64": 64, "i32": 32, "u32": 32, "i64": 64, "u64": 64, "bool": None}[result["dst"]]
    expected = str(int(value, 16) != 0).lower() if width is None else f"{width}:{value}"
    print(function, *arguments, result["flags"], expected)


one = "0x3ff0000000000000"
two = "0x4000000000000000"
three = "0x4008000000000000"
minus_one = "0xbff0000000000000"
positive_zero = "0x0000000000000000"
negative_zero = "0x8000000000000000"
positive_inf = "0x7ff0000000000000"
negative_inf = "0xfff0000000000000"
qnan = "0x7ff8000000000001"
snan = "0x7ff0000000000001"
maximum = "0x7fefffffffffffff"
minimum_normal = "0x0010000000000000"
minimum_subnormal = "0x0000000000000001"

for op, function in (("eq", "riscv_f64Eq"), ("lt", "riscv_f64Lt"),
                     ("lt_quiet", "riscv_f64Lt_quiet"), ("le", "riscv_f64Le"),
                     ("le_quiet", "riscv_f64Le_quiet")):
    for a, b in ((one, two), (positive_zero, negative_zero), (qnan, one), (snan, one)):
        case(function, [f"64:{a}", f"64:{b}"], op, a=a, b=b)

for op, function in (("add", "riscv_f64Add"), ("sub", "riscv_f64Sub"),
                     ("mul", "riscv_f64Mul"), ("div", "riscv_f64Div")):
    for rm in range(5):
        a, b = ((one, three) if op == "div" else (maximum, two))
        case(function, [f"3:{rm:x}", f"64:{a}", f"64:{b}"], op, rm=rm, a=a, b=b)
    for a, b in ((positive_inf, negative_inf), (positive_zero, positive_zero),
                 (snan, one), (minimum_normal, minimum_subnormal)):
        case(function, ["3:0", f"64:{a}", f"64:{b}"], op, rm=0, a=a, b=b)

for rm in range(5):
    case("riscv_f64Sqrt", [f"3:{rm:x}", f"64:{two}"], "sqrt", rm=rm, a=two)
    case("riscv_f64MulAdd", [f"3:{rm:x}", f"64:{one}", f"64:{two}", f"64:{three}"],
         "fma", rm=rm, a=one, b=two, c=three)
for a in (minus_one, negative_zero, snan, positive_inf):
    case("riscv_f64Sqrt", ["3:0", f"64:{a}"], "sqrt", rm=0, a=a)
for a, b, c in ((positive_zero, positive_inf, qnan), (positive_inf, one, negative_inf),
                (minimum_subnormal, minimum_subnormal, minimum_subnormal)):
    case("riscv_f64MulAdd", ["3:0", f"64:{a}", f"64:{b}", f"64:{c}"],
         "fma", rm=0, a=a, b=b, c=c)

for exact in (0, 1):
    for a in ("0x3ff8000000000000", snan, negative_zero):
        case("riscv_f64roundToInt", ["3:0", f"64:{a}", str(bool(exact)).lower()],
             "round", rm=0, a=a, exact=exact)
    for rm in range(5):
        for a in ("0x3ff8000000000000", "0xbff8000000000000",
                  "0x4004000000000000", "0xc004000000000000"):
            case("riscv_f64roundToInt", [f"3:{rm:x}", f"64:{a}", str(bool(exact)).lower()],
                 "round", rm=rm, a=a, exact=exact)

for dst, function in (("i32", "riscv_f64ToI32"), ("u32", "riscv_f64ToUi32"),
                      ("i64", "riscv_f64ToI64"), ("u64", "riscv_f64ToUi64")):
    for a in ("0x3ff8000000000000", "0xbfe0000000000000", qnan, positive_inf,
              "0x41e0000000000000", "0xc1e0000000200000",
              "0xfff8000000000001", "0xfff0000000000001"):
        case(function, ["3:0", f"64:{a}"], "fp_to_int", rm=0, a=a, dst=dst)
    for value in (2**31 - 0.25, -2**31 - 0.25, -0.25,
                  math.nextafter(float(2**63), -math.inf), float(2**63),
                  math.nextafter(float(2**64), -math.inf), float(2**64)):
        a = f"0x{struct.unpack('>Q', struct.pack('>d', value))[0]:016x}"
        for rm in range(5):
            case(function, [f"3:{rm:x}", f"64:{a}"], "fp_to_int", rm=rm, a=a, dst=dst)

for fmt, function, width in (("i32", "riscv_i32ToF64", 32), ("u32", "riscv_ui32ToF64", 32),
                             ("i64", "riscv_i64ToF64", 64), ("u64", "riscv_ui64ToF64", 64)):
    for rm in range(5):
        a = "0x7fffffffffffffff" if width == 64 else "0xffffffff"
        case(function, [f"3:{rm:x}", f"{width}:{a}"], "int_to_fp", fmt=fmt, rm=rm, a=a, dst="f64")
for rm in range(5):
    for a in ("0x8000000000000000", "0x8000000000000001",
              "0x8000000000000400", "0x8000000000000800",
              "0xffffffffffffffff"):
        case("riscv_i64ToF64", [f"3:{rm:x}", f"64:{a}"],
             "int_to_fp", fmt="i64", rm=rm, a=a, dst="f64")

for dst, function in (("f16", "riscv_f64ToF16"), ("f32", "riscv_f64ToF32")):
    for rm in range(5):
        case(function, [f"3:{rm:x}", f"64:{maximum}"], "fp_to_fp", rm=rm, a=maximum, dst=dst)
    for a in (minimum_subnormal, qnan, snan, negative_zero, "0x3ff0000000000001"):
        case(function, ["3:0", f"64:{a}"], "fp_to_fp", rm=0, a=a, dst=dst)
case("riscv_f64ToF32", ["3:6", "64:0x3ff0000000000001"], "fp_to_fp",
     rm=6, a="0x3ff0000000000001", dst="f32")
for a in (positive_inf, negative_inf, qnan, "0xfff8000000000001",
          snan, "0xfff0000000000001", positive_zero, negative_zero,
          minimum_subnormal, "0x8000000000000001"):
    case("riscv_f64ToF32", ["3:6", f"64:{a}"], "fp_to_fp",
         rm=6, a=a, dst="f32")

for dst, function, precision, emin, emax, modes in (
    ("f16", "riscv_f64ToF16", 11, -14, 15, range(5)),
    ("f32", "riscv_f64ToF32", 24, -126, 127, (*range(5), 6)),
):
    high = math.ldexp(1.0, emax + 1)
    gap = math.ldexp(1.0, emax - precision + 1)
    normal = math.ldexp(1.0, emin)
    boundaries = (
        high - gap, high - gap / 2, high,
        normal - math.ldexp(1.0, emin - precision),
        normal - math.ldexp(1.0, emin - precision - 1), normal,
    )
    for boundary in boundaries:
        for value in (math.nextafter(boundary, -math.inf), boundary,
                      math.nextafter(boundary, math.inf)):
            for signed in (value, -value):
                a = f"0x{struct.unpack('>Q', struct.pack('>d', signed))[0]:016x}"
                for rm in modes:
                    case(function, [f"3:{rm:x}", f"64:{a}"], "fp_to_fp",
                         rm=rm, a=a, dst=dst)

# Seeded, bounded random coverage is a differential sample, never an exhaustive proof.
rng = random.Random(0xF64026)
for _ in range(2):
    a, b, c = (f"0x{rng.getrandbits(64):016x}" for _ in range(3))
    rm = rng.randrange(5)
    for op, function in (("eq", "riscv_f64Eq"), ("lt", "riscv_f64Lt"),
                         ("lt_quiet", "riscv_f64Lt_quiet"), ("le", "riscv_f64Le"),
                         ("le_quiet", "riscv_f64Le_quiet")):
        case(function, [f"64:{a}", f"64:{b}"], op, a=a, b=b)
    for op, function in (("add", "riscv_f64Add"), ("sub", "riscv_f64Sub"),
                         ("mul", "riscv_f64Mul"), ("div", "riscv_f64Div")):
        case(function, [f"3:{rm:x}", f"64:{a}", f"64:{b}"], op, rm=rm, a=a, b=b)
    case("riscv_f64Sqrt", [f"3:{rm:x}", f"64:{a}"], "sqrt", rm=rm, a=a)
    case("riscv_f64MulAdd", [f"3:{rm:x}", f"64:{a}", f"64:{b}", f"64:{c}"],
         "fma", rm=rm, a=a, b=b, c=c)
    case("riscv_f64roundToInt", [f"3:{rm:x}", f"64:{a}", "true"],
         "round", rm=rm, a=a, exact=1)
    for dst, function in (("i32", "riscv_f64ToI32"), ("u32", "riscv_f64ToUi32"),
                          ("i64", "riscv_f64ToI64"), ("u64", "riscv_f64ToUi64")):
        case(function, [f"3:{rm:x}", f"64:{a}"], "fp_to_int", rm=rm, a=a, dst=dst)
    for fmt, function, width in (("i32", "riscv_i32ToF64", 32), ("u32", "riscv_ui32ToF64", 32),
                                 ("i64", "riscv_i64ToF64", 64), ("u64", "riscv_ui64ToF64", 64)):
        integer = f"0x{rng.getrandbits(width):0{width // 4}x}"
        case(function, [f"3:{rm:x}", f"{width}:{integer}"], "int_to_fp",
             fmt=fmt, rm=rm, a=integer, dst="f64")
    for dst, function in (("f16", "riscv_f64ToF16"), ("f32", "riscv_f64ToF32")):
        case(function, [f"3:{rm:x}", f"64:{a}"], "fp_to_fp", rm=rm, a=a, dst=dst)
