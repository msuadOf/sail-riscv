#!/usr/bin/env python3
"""Compare isolated Sail/Isla IEEE probes with RISC-V Berkeley SoftFloat."""

import argparse
import json
import random
import subprocess


FORMATS = {
    16: dict(zero=0x0000, negzero=0x8000, minsub=0x0001, maxsub=0x03FF,
             minnormal=0x0400, half=0x3800, one=0x3C00, two=0x4000,
             three=0x4200, half_ulp=0x1000, maximum=0x7BFF,
             inf=0x7C00, neginf=0xFC00, qnan=0x7E00, snan=0x7D00),
    32: dict(zero=0x00000000, negzero=0x80000000, minsub=0x00000001,
             maxsub=0x007FFFFF, minnormal=0x00800000, half=0x3F000000,
             one=0x3F800000, two=0x40000000, three=0x40400000,
             half_ulp=0x33800000, maximum=0x7F7FFFFF,
             inf=0x7F800000, neginf=0xFF800000,
             qnan=0x7FC00000, snan=0x7F800001),
    64: dict(zero=0x0000000000000000, negzero=0x8000000000000000,
             minsub=0x0000000000000001, maxsub=0x000FFFFFFFFFFFFF,
             minnormal=0x0010000000000000, half=0x3FE0000000000000,
             one=0x3FF0000000000000, two=0x4000000000000000,
             three=0x4008000000000000, half_ulp=0x3CA0000000000000,
             maximum=0x7FEFFFFFFFFFFFFF, inf=0x7FF0000000000000,
             neginf=0xFFF0000000000000, qnan=0x7FF8000000000000,
             snan=0x7FF0000000000001),
}


def fixed_cases(width):
    f = FORMATS[width]
    negative_maximum = f["maximum"] | (1 << (width - 1))
    return {
        "add": [(f["one"], f["two"]), (f["one"], f["half_ulp"]),
                (f["maximum"], f["maximum"]), (f["one"], f["inf"]),
                (f["inf"], f["one"]), (f["inf"], f["neginf"]),
                (f["minsub"], f["minsub"]), (f["snan"], f["one"])],
        "sub": [(f["one"], f["two"]), (f["one"], f["half_ulp"]),
                (f["inf"], f["inf"]), (f["minnormal"], f["maxsub"]),
                (f["maximum"], negative_maximum)],
        "mul": [(f["one"], f["two"]), (f["maximum"], f["two"]),
                (f["minsub"], f["half"]), (f["minnormal"], f["half"]),
                (f["zero"], f["inf"]), (f["inf"], f["one"])],
        "div": [(f["one"], f["three"]), (f["maximum"], f["minsub"]),
                (f["minsub"], f["maximum"]), (f["one"], f["zero"]),
                (f["zero"], f["zero"]), (f["inf"], f["inf"]),
                (f["inf"], f["zero"]), (f["one"], f["inf"])],
        "sqrt": [(f["two"],), (f["one"],), (f["minsub"],),
                 (f["one"] | (1 << (width - 1)),), (f["negzero"],),
                 (f["inf"],), (f["neginf"],), (f["qnan"],), (f["snan"],)],
        "fma": [(f["two"], f["three"], f["one"]),
                (f["minsub"], f["minsub"], f["zero"]),
                (f["maximum"], f["two"], negative_maximum),
                (f["zero"], f["inf"], f["qnan"]),
                (f["inf"], f["one"], f["neginf"]),
                (f["one"], f["two"], f["inf"])],
    }


def comparison_cases(width):
    f = FORMATS[width]
    pairs = [(f["one"], f["one"]), (f["zero"], f["negzero"]),
             (f["zero"], f["one"]), (f["inf"], f["neginf"]),
             (f["qnan"], f["one"]), (f["snan"], f["one"])]
    return {op: pairs for op in ("eq", "eq_signaling", "lt", "lt_quiet", "le", "le_quiet")}


def is_nan(bits, width):
    exponent_width, fraction_width = {16: (5, 10), 32: (8, 23), 64: (11, 52)}[width]
    return ((bits >> fraction_width) & ((1 << exponent_width) - 1)) == ((1 << exponent_width) - 1) and (bits & ((1 << fraction_width) - 1)) != 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--probe", required=True)
    parser.add_argument("--ir", required=True)
    parser.add_argument("--oracle", required=True)
    parser.add_argument("--random-per-op", type=int, default=0)
    parser.add_argument("--prove", action="store_true", help="require a SAT sample then UNSAT for different flags or non-NaN result")
    args = parser.parse_args()
    rng = random.Random(0x1EEEF)
    cases = []
    for width in FORMATS:
        for op, operands_list in fixed_cases(width).items():
            for rm in range(5):
                for operands in operands_list:
                    cases.append((op, width, rm, operands))
            for _ in range(args.random_per_op):
                operands = tuple(rng.getrandbits(width) for _ in range(1 if op == "sqrt" else 3 if op == "fma" else 2))
                cases.append((op, width, rng.randrange(5), operands))
        for op, operands_list in comparison_cases(width).items():
            for operands in operands_list:
                cases.append((op, width, 0, operands))

    lines = []
    expected_values = []
    for op, width, rm, operands in cases:
        comparison = op in ("eq", "eq_signaling", "lt", "lt_quiet", "le", "le_quiet")
        command = [args.oracle, "--op", op, "--fmt", f"f{width}"]
        if not comparison:
            command += ["--rm", str(rm)]
        for name, value in zip("abc", operands):
            command += [f"--{name}", f"0x{value:0{width // 4}x}"]
        expected = json.loads(subprocess.check_output(command, text=True))
        expected_values.append(expected)
        fields = [op, str(width), str(rm), *(f"{operand:x}" for operand in operands)]
        if args.prove:
            fields += [expected["flags"], expected["result_bits"],
                       "1" if not comparison and is_nan(int(expected["result_bits"], 16), width) else "0"]
        lines.append(" ".join(fields))
    probe_command = [args.probe, args.ir] + (["--prove"] if args.prove else [])
    probe = subprocess.run(probe_command, input="\n".join(lines) + "\n",
                           text=True, capture_output=True)
    if probe.returncode:
        raise RuntimeError(f"probe failed after {len(probe.stdout.splitlines())} cases: {probe.stderr}")
    observed = probe.stdout.splitlines()
    if len(observed) != len(cases):
        raise RuntimeError(f"probe returned {len(observed)} lines for {len(cases)} cases")
    failures = []
    for case, output, expected in zip(cases, observed, expected_values):
        op, width, rm, operands = case
        comparison = op in ("eq", "eq_signaling", "lt", "lt_quiet", "le", "le_quiet")
        actual_flags, actual_bits = (int(value, 16) for value in output.split())
        expected_flags = int(expected["flags"], 16)
        expected_bits = int(expected["result_bits"], 16)
        if actual_flags != expected_flags or ((comparison or not is_nan(expected_bits, width)) and actual_bits != expected_bits):
            failures.append((case, output, expected))
            if len(failures) >= 12:
                break
    for case, output, expected in failures:
        print(f"FAIL {case}: Isla={output}, SoftFloat={expected['flags']} {expected['result_bits']}")
    if failures:
        raise SystemExit(1)
    print(f"PASS {len(cases)} isolated cases: bits (non-NaN) and all five flags; uniqueness proof={args.prove}")


if __name__ == "__main__":
    main()
