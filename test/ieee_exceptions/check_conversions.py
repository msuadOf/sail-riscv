#!/usr/bin/env python3
"""Check shared conversion and ROD exceptions against RISC-V SoftFloat."""

import argparse
import json
import random
import subprocess
from check import FORMATS, is_nan


def is_bf16_nan(bits):
    return ((bits >> 7) & 0xff) == 0xff and (bits & 0x7f) != 0


def generate(random_count):
    rng = random.Random(0xC0A74)
    for src_width, f in FORMATS.items():
        values = [f[k] for k in ("zero", "negzero", "minsub", "maxsub", "minnormal",
                                 "half", "one", "two", "maximum", "inf", "neginf", "qnan", "snan")]
        values += [f["half"] | (1 << (src_width - 1))]
        values += [rng.getrandbits(src_width) for _ in range(random_count)]
        if src_width == 32:
            values += [0x387FE000, 0x387FF000, 0x387FF001, 0x477FE000, 0x477FF000]
        if src_width == 64:
            values += [0x380FFFFFE0000000, 0x380FFFFFF0000000,
                       0x47EFFFFFE0000000, 0x47EFFFFFF0000000]
        for rm in range(5):
            for raw in values:
                for exact in (0, 1):
                    yield ("round", src_width, src_width, rm, (raw, exact),
                           ["--op", "round", "--fmt", f"f{src_width}", "--rm", str(rm),
                            "--a", hex(raw), "--exact", str(exact)], False)
                for dst in ("i32", "u32", "i64", "u64"):
                    yield (f"fp_to_{dst}", src_width, int(dst[1:]), rm, (raw,),
                           ["--op", "fp_to_int", "--fmt", f"f{src_width}", "--dst", dst,
                            "--rm", str(rm), "--a", hex(raw)], True)
                for dst_width in (16, 32, 64):
                    if dst_width != src_width:
                        yield (f"fp_to_fp{dst_width}", src_width, dst_width, rm, (raw,),
                               ["--op", "fp_to_fp", "--fmt", f"f{src_width}", "--dst", f"f{dst_width}",
                                "--rm", str(rm), "--a", hex(raw)], False)
                if src_width == 32:
                    yield ("fp_to_bf16", 32, 16, rm, (raw,),
                           ["--op", "fp_to_fp", "--fmt", "f32", "--dst", "bf16",
                            "--rm", str(rm), "--a", hex(raw)], False)
        if src_width in (32, 64):
            dst_width = 16 if src_width == 32 else 32
            for raw in values:
                yield ("rod", src_width, dst_width, 6, (raw,),
                       ["--op", "fp_to_fp", "--fmt", f"f{src_width}", "--dst", f"f{dst_width}",
                        "--rm", "6", "--a", hex(raw)], False)
    for int_width in (32, 64):
        mask = (1 << int_width) - 1
        values = [0, 1, 65505, 65520, -65520 & mask,
                  (1 << (int_width - 1)) - 1, 1 << (int_width - 1), mask]
        values += [rng.getrandbits(int_width) for _ in range(random_count)]
        for prefix in ("i", "u"):
            src = f"{prefix}{int_width}"
            for dst_width in (16, 32, 64):
                for rm in range(5):
                    for raw in values:
                        yield (f"{src}_to_fp", dst_width, dst_width, rm, (raw,),
                               ["--op", "int_to_fp", "--fmt", src, "--dst", f"f{dst_width}",
                                "--rm", str(rm), "--a", hex(raw)], False)


def main():
    p = argparse.ArgumentParser()
    for key in ("probe", "ir", "oracle"):
        p.add_argument(f"--{key}", required=True)
    p.add_argument("--random-per-source", type=int, default=0)
    p.add_argument("--prove", action="store_true")
    args = p.parse_args()
    cases = list(generate(args.random_per_source))
    expected = [json.loads(subprocess.check_output([args.oracle, *case[5]], text=True))
                for case in cases]
    lines = []
    skips = []
    for case, oracle in zip(cases, expected):
        op, src_width, dst_width, rm, inputs, _, fp_to_int = case
        flags = int(oracle["flags"], 16)
        bits = int(oracle["result_bits"], 16)
        nan_result = is_bf16_nan(bits) if op == "fp_to_bf16" else is_nan(bits, dst_width)
        skip = bool(fp_to_int and flags & 0x10) or bool(not fp_to_int and nan_result)
        skips.append(skip)
        fields = [op, str(src_width), str(rm), *(f"{value:x}" for value in inputs)]
        if args.prove:
            fields += [oracle["flags"], oracle["result_bits"], str(int(skip))]
        lines.append(" ".join(fields))
    command = [args.probe, args.ir] + (["--prove"] if args.prove else [])
    run = subprocess.run(command, input="\n".join(lines) + "\n", text=True, capture_output=True)
    if run.returncode:
        raise RuntimeError(f"probe failed after {len(run.stdout.splitlines())}/{len(lines)} cases: {run.stderr}")
    outputs = run.stdout.splitlines()
    if len(outputs) != len(cases):
        raise RuntimeError(f"probe returned {len(outputs)}/{len(cases)} cases")
    failures = []
    for case, oracle, output, skip in zip(cases, expected, outputs, skips):
        flags, bits = (int(part, 16) for part in output.split())
        want_flags, want_bits = int(oracle["flags"], 16), int(oracle["result_bits"], 16)
        if flags != want_flags or (not skip and bits != want_bits):
            failures.append((case[:5], output, oracle["flags"], oracle["result_bits"]))
            if len(failures) >= 12:
                break
    for case, actual, flags, bits in failures:
        print(f"FAIL {case}: Isla={actual}, SoftFloat={flags} {bits}")
    if failures:
        raise SystemExit(1)
    print(f"PASS {len(cases)} conversion/round/ROD cases; uniqueness proof={args.prove}")


if __name__ == "__main__":
    main()
