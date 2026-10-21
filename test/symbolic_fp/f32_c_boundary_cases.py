#!/usr/bin/env python3
"""Generate deterministic f32 boundary cases with independent SoftFloat results.

The bit patterns cover BF16 subnormal/normal and finite/infinite thresholds,
FP-to-integer rounding boundaries for both widths, and both the ROD result
and its ordinary RTZ candidate at the f16 underflow/overflow thresholds.
"""

import argparse
import json
import subprocess


def signed_pairs(positive):
    for value in positive:
        yield value
    for value in positive:
        yield value | 0x80000000


BF16_POSITIVE = (
    0x00000000,
    0x007EFFFF, 0x007F0000, 0x007F0001, 0x007F7FFF,
    0x007F8000, 0x007F8001, 0x007FFFFF, 0x00800000, 0x00800001,
    0x7F7EFFFF, 0x7F7F0000, 0x7F7F0001, 0x7F7F7FFF,
    0x7F7F8000, 0x7F7F8001, 0x7F7FFFFE, 0x7F7FFFFF,
    0x7F800000, 0x7F800001, 0x7FC00001,
)

INTEGER_POSITIVE = (
    0x00000000,
    0x3EFFFFFF, 0x3F000000, 0x3F000001,
    0x3F7FFFFF, 0x3F800000, 0x3F800001,
    0x4EFFFFFF, 0x4F000000, 0x4F000001,
    0x4F7FFFFF, 0x4F800000, 0x4F800001,
    0x5EFFFFFF, 0x5F000000, 0x5F000001,
    0x5F7FFFFF, 0x5F800000, 0x5F800001,
    0x7F800000, 0x7F800001, 0x7FC00001,
)

ROD_POSITIVE = (
    0x00000000,
    0x387FDFFF, 0x387FE000, 0x387FE001,
    0x387FEFFF, 0x387FF000, 0x387FF001,
    0x387FFFFF, 0x38800000, 0x38800001,
    0x477FDFFF, 0x477FE000, 0x477FE001,
    0x477FEFFF, 0x477FF000, 0x477FF001,
    0x477FFFFF, 0x47800000, 0x47800001,
    0x7F800000, 0x7F800001, 0x7FC00001,
)


def result(oracle, op, dst, rm, value):
    command = [oracle, "--op", op, "--fmt", "f32", "--dst", dst,
               "--rm", str(rm), "--a", f"0x{value:08x}"]
    return json.loads(subprocess.check_output(command, text=True))


def emit(output, helper, width, rm, value, expected):
    output.write(f"{helper} 32 {width} {rm} {value:x} 0 "
                 f"{expected['flags']} {expected['result_bits']}\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--oracle", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    count = 0
    with open(args.output, "w") as output:
        for rm in range(5):
            for value in signed_pairs(BF16_POSITIVE):
                emit(output, "riscv_f32ToBF16", 16, rm, value,
                     result(args.oracle, "fp_to_fp", "bf16", rm, value))
                count += 1
        for helper, target, width in (
            ("riscv_f32ToI32", "i32", 32),
            ("riscv_f32ToUi32", "u32", 32),
            ("riscv_f32ToI64", "i64", 64),
            ("riscv_f32ToUi64", "u64", 64),
        ):
            for rm in range(5):
                for value in signed_pairs(INTEGER_POSITIVE):
                    emit(output, helper, width, rm, value,
                         result(args.oracle, "fp_to_int", target, rm, value))
                    count += 1
        for helper, reference_rm in (("riscv_f32ToF16", 6),
                                     ("f32_rod_normal_candidate", 1)):
            for value in signed_pairs(ROD_POSITIVE):
                emit(output, helper, 16, 6, value,
                     result(args.oracle, "fp_to_fp", "f16", reference_rm, value))
                count += 1
    assert count == 1178, count
    print(f"wrote {count} deterministic f32 boundary cases to {args.output}")


if __name__ == "__main__":
    main()
