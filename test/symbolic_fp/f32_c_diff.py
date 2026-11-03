#!/usr/bin/env python3
"""Compare production f32 SYMBOLIC wrappers with the independent SoftFloat oracle."""

import argparse
import json
import random
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ieee_exceptions"))
from check import FORMATS, comparison_cases, fixed_cases  # noqa: E402


def cases(random_per_op):
    f = FORMATS[32]
    fixed = fixed_cases(32)
    fixed["add"] += [(f["qnan"], f["one"]), (f["one"], f["qnan"])]
    fixed["sub"] += [(f["one"], f["half_ulp"] | 0x80000000)]
    fixed["mul"] += [(f["qnan"], f["one"])]
    fixed["div"] += [(f["qnan"], f["one"])]
    fixed["fma"] += [(f["qnan"], f["one"], f["one"])]
    rng = random.Random(0xF32C)
    for op, operands_list in fixed.items():
        for rm in range(5):
            for operands in operands_list:
                yield op, rm, operands
        for _ in range(random_per_op):
            count = 1 if op == "sqrt" else 3 if op == "fma" else 2
            yield op, rng.randrange(5), tuple(rng.getrandbits(32) for _ in range(count))
    for op, operands_list in comparison_cases(32).items():
        if op == "eq_signaling":
            continue  # No f32 signaling Eq helper is declared in the model.
        for operands in operands_list:
            yield op, 0, operands


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--oracle", required=True)
    parser.add_argument("--probe", required=True)
    parser.add_argument("--ir", required=True)
    parser.add_argument("--random-per-op", type=int, default=0)
    args = parser.parse_args()
    selected = list(cases(args.random_per_op))
    requests = []
    expected = []
    for op, rm, operands in selected:
        command = [args.oracle, "--op", op, "--fmt", "f32"]
        if op not in ("eq", "lt", "lt_quiet", "le", "le_quiet"):
            command += ["--rm", str(rm)]
        for name, operand in zip("abc", operands):
            command += [f"--{name}", f"0x{operand:08x}"]
        result = json.loads(subprocess.check_output(command, text=True))
        expected.append(result)
        requests.append(" ".join([op, "32", str(rm), *(f"{x:x}" for x in operands),
                                  result["flags"], result["result_bits"], "0"]))

    run = subprocess.run([args.probe, args.ir, "--prove"], input="\n".join(requests) + "\n",
                         text=True, capture_output=True)
    if run.returncode:
        raise RuntimeError(f"probe failed after {len(run.stdout.splitlines())}/{len(selected)} cases: {run.stderr}")
    observed = run.stdout.splitlines()
    if len(observed) != len(selected):
        raise RuntimeError(f"probe returned {len(observed)}/{len(selected)} cases")
    for case, line, reference in zip(selected, observed, expected):
        flags, result = (int(part, 16) for part in line.split())
        if flags != int(reference["flags"], 16) or result != int(reference["result_bits"], 16):
            raise RuntimeError(f"{case}: Isla={line}, SoftFloat={reference}")
    print(f"PASS {len(selected)} f32 wrapper cases: exact bits, five flags, one path, SAT and mismatch UNSAT")


if __name__ == "__main__":
    main()
