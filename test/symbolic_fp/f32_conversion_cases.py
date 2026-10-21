#!/usr/bin/env python3
"""Write independent SoftFloat expectations for every f32 conversion helper."""

import argparse
import json
import random
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--oracle", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--random-per-helper", type=int, default=0)
    args = parser.parse_args()
    rng = random.Random(0xC0F32)
    fp = [0x00000000, 0x80000000, 0x00000001, 0x007fffff, 0x00800000,
          0x3f800000, 0x3fc00000, 0xbf800000, 0xbfc00000, 0x4effffff,
          0x4f000000, 0xcf000000, 0x5f000000, 0x7f7fffff, 0x7f800000,
          0xff800000, 0x7fc00000, 0x7f800001, 0x3f800800,
          0x387fdfff, 0x387fe000, 0x387fe001, 0x387fefff,
          0x387ff000, 0x387ff001, 0x387fffff, 0x38800000,
          0xb87fdfff, 0xb87fe000, 0xb87fe001, 0xb87fefff,
          0xb87ff000, 0xb87ff001, 0xb87fffff, 0xb8800000]
    i32 = [0, 1, 0xffffffff, 0x00ffffff, 0x01000001, 0x7fffffff, 0x80000000]
    i64 = [0, 1, 0xffffffffffffffff, 0x01000001, 0x7fffffffffffffff,
           0x8000000000000000, 0xffffffffffff0000]
    specs = [
        ("riscv_f32ToI32", "f32", "i32", 32, 32, fp),
        ("riscv_f32ToUi32", "f32", "u32", 32, 32, fp),
        ("riscv_f32ToI64", "f32", "i64", 32, 64, fp),
        ("riscv_f32ToUi64", "f32", "u64", 32, 64, fp),
        ("riscv_i32ToF32", "i32", "f32", 32, 32, i32),
        ("riscv_ui32ToF32", "u32", "f32", 32, 32, i32),
        ("riscv_i64ToF32", "i64", "f32", 64, 32, i64),
        ("riscv_ui64ToF32", "u64", "f32", 64, 32, i64),
        ("riscv_f32ToF16", "f32", "f16", 32, 16, fp),
        ("riscv_f32ToF64", "f32", "f64", 32, 64, fp),
        ("riscv_f32ToBF16", "f32", "bf16", 32, 16, fp),
        ("riscv_f32roundToInt", "f32", "f32", 32, 32, fp),
    ]
    count = 0
    with open(args.output, "w") as output:
        for helper, source, target, input_width, result_width, fixed in specs:
            inputs = fixed + [rng.getrandbits(input_width) for _ in range(args.random_per_helper)]
            for rm in ([0, 1, 2, 3, 4, 6] if helper == "riscv_f32ToF16" else range(5)):
                for value in inputs:
                    exact_options = (False, True) if helper == "riscv_f32roundToInt" else (False,)
                    for exact in exact_options:
                        if helper == "riscv_f32roundToInt":
                            operation = "round"
                        elif source.startswith("f") and target[0] in "iu":
                            operation = "fp_to_int"
                        elif source[0] in "iu":
                            operation = "int_to_fp"
                        else:
                            operation = "fp_to_fp"
                        command = [args.oracle, "--op", operation, "--fmt", source,
                                   "--rm", str(rm), "--a", f"0x{value:0{input_width // 4}x}"]
                        if operation != "round":
                            command += ["--dst", target]
                        else:
                            command += ["--exact", str(int(exact))]
                        reference = json.loads(subprocess.check_output(command, text=True))
                        output.write(f"{helper} {input_width} {result_width} {rm} {value:x} "
                                     f"{int(exact)} {reference['flags']} {reference['result_bits']}\n")
                        count += 1
        for value in (0x3f800800, 0xbf800800, 0x387fe000, 0x7f7fffff):
            # The production ROD wrapper maps its ordinary candidate to RTZ.
            reference = json.loads(subprocess.check_output([
                args.oracle, "--op", "fp_to_fp", "--fmt", "f32", "--dst", "f16",
                "--rm", "1", "--a", f"0x{value:08x}"], text=True))
            output.write(f"f32_rod_normal_candidate 32 16 6 {value:x} 0 "
                         f"{reference['flags']} {reference['result_bits']}\n")
            count += 1
    print(f"wrote {count} SoftFloat cases to {args.output}")


if __name__ == "__main__":
    main()
