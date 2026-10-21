#!/usr/bin/env python3
"""Compare every f16 SYMBOLIC wrapper with the independent SoftFloat oracle."""

import argparse
import json
import random
import subprocess


VALUES = [0x0000, 0x8000, 0x0001, 0x03FF, 0x0400, 0x3C00,
          0x4000, 0x7BFF, 0x7C00, 0xFC00, 0x7E00, 0x7D00]
PAIRS = [(0x3C00, 0x4000), (0x0000, 0x8000), (0x7BFF, 0x4000),
         (0x0001, 0x03FF), (0x7C00, 0xFC00), (0x0000, 0x7C00),
         (0x3C00, 0x0000), (0x7E00, 0x3C00), (0x7D00, 0x3C00)]
TRIPLES = [(0x3C00, 0x4000, 0x3C00), (0x0001, 0x0001, 0x0000),
           (0x0000, 0x7C00, 0x7E00), (0x7C00, 0x3C00, 0xFC00)]
INT32 = [0, 1, 0xFFFFFFFF, 0x0000FFE1, 0x0000FFFF,
         0xFFFF0010,  # signed -65520: RUP must set NX without OF
         0x7FFFFFFF, 0x80000000]
INT64 = [0, 1, 0xFFFFFFFFFFFFFFFF, 0x000000000000FFE1,
         0xFFFFFFFFFFFF0010,  # signed -65520, same f16 boundary
         0x7FFFFFFFFFFFFFFF, 0x8000000000000000]


def cases(quick, random_per_op):
    modes = [0] if quick else range(5)
    for op, helper in [('add', 'riscv_f16Add'), ('sub', 'riscv_f16Sub'),
                       ('mul', 'riscv_f16Mul'), ('div', 'riscv_f16Div')]:
        for rm in modes:
            for pair in PAIRS[:3] if quick else PAIRS:
                yield helper, op, 'f16', None, rm, pair, None
    for rm in modes:
        for triple in TRIPLES[:2] if quick else TRIPLES:
            yield 'riscv_f16MulAdd', 'fma', 'f16', None, rm, triple, None
        for value in VALUES[:5] if quick else VALUES:
            yield 'riscv_f16Sqrt', 'sqrt', 'f16', None, rm, (value,), None
    for op, helper in [('lt', 'riscv_f16Lt'), ('lt_quiet', 'riscv_f16Lt_quiet'),
                       ('le', 'riscv_f16Le'), ('le_quiet', 'riscv_f16Le_quiet'),
                       ('eq', 'riscv_f16Eq')]:
        for pair in PAIRS[:3] if quick else PAIRS:
            yield helper, op, 'f16', None, None, pair, None
    for rm in modes:
        for value in VALUES[:5] if quick else VALUES:
            for exact in (False, True):
                yield 'riscv_f16roundToInt', 'round', 'f16', None, rm, (value,), exact
            for dst, suffix in [('i32', 'I32'), ('u32', 'Ui32'),
                                ('i64', 'I64'), ('u64', 'Ui64')]:
                yield 'riscv_f16To' + suffix, 'fp_to_int', 'f16', dst, rm, (value,), None
        for src, prefix, values in [('i32', 'i32', INT32), ('u32', 'ui32', INT32),
                                    ('i64', 'i64', INT64), ('u64', 'ui64', INT64)]:
            for value in values[:3] if quick else values:
                yield 'riscv_' + prefix + 'ToF16', 'int_to_fp', src, 'f16', rm, (value,), None
    for value in VALUES[:5] if quick else VALUES:
        for dst in ('f32', 'f64'):
            yield 'riscv_f16To' + dst.upper(), 'fp_to_fp', 'f16', dst, 0, (value,), None

    # These three call sites make rm/input bits symbolic before constraining
    # them to oracle examples. The Rust probe checks reachability and UNSAT
    # of a different result or flag in the same single execution path.
    yield 'f16_wrapper_unknown_add', 'add', 'f16', None, 3, (0x7BFF, 0x4000), None
    yield 'f16_wrapper_unknown_eq', 'eq', 'f16', None, None, (0x7D00, 0x3C00), None
    yield 'f16_wrapper_unknown_i32_to_f16', 'int_to_fp', 'i32', 'f16', 1, (0x0000FFE1,), None

    rng = random.Random(0xF1616)
    for _ in range(random_per_op):
        rm = rng.randrange(5)
        for op, helper in [('add', 'riscv_f16Add'), ('sub', 'riscv_f16Sub'),
                           ('mul', 'riscv_f16Mul'), ('div', 'riscv_f16Div')]:
            yield helper, op, 'f16', None, rm, (rng.getrandbits(16), rng.getrandbits(16)), None
        yield 'riscv_f16MulAdd', 'fma', 'f16', None, rm, tuple(rng.getrandbits(16) for _ in range(3)), None
        yield 'riscv_f16Sqrt', 'sqrt', 'f16', None, rm, (rng.getrandbits(16),), None
        for op, helper in [('lt', 'riscv_f16Lt'), ('lt_quiet', 'riscv_f16Lt_quiet'),
                           ('le', 'riscv_f16Le'), ('le_quiet', 'riscv_f16Le_quiet'),
                           ('eq', 'riscv_f16Eq')]:
            yield helper, op, 'f16', None, None, (rng.getrandbits(16), rng.getrandbits(16)), None
        value = rng.getrandbits(16)
        yield 'riscv_f16roundToInt', 'round', 'f16', None, rm, (value,), bool(rng.getrandbits(1))
        for dst, suffix in [('i32', 'I32'), ('u32', 'Ui32'),
                            ('i64', 'I64'), ('u64', 'Ui64')]:
            yield 'riscv_f16To' + suffix, 'fp_to_int', 'f16', dst, rm, (value,), None
        for src, prefix, width in [('i32', 'i32', 32), ('u32', 'ui32', 32),
                                   ('i64', 'i64', 64), ('u64', 'ui64', 64)]:
            yield 'riscv_' + prefix + 'ToF16', 'int_to_fp', src, 'f16', rm, (rng.getrandbits(width),), None
        for dst in ('f32', 'f64'):
            yield 'riscv_f16To' + dst.upper(), 'fp_to_fp', 'f16', dst, rm, (value,), None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--oracle', required=True)
    parser.add_argument('--probe', required=True)
    parser.add_argument('--ir', required=True)
    parser.add_argument('--quick', action='store_true')
    parser.add_argument('--random-per-op', type=int, default=0)
    args = parser.parse_args()
    lines = []
    for helper, op, fmt, dst, rm, operands, exact in cases(args.quick, args.random_per_op):
        command = [args.oracle, '--op', op, '--fmt', fmt]
        if dst:
            command += ['--dst', dst]
        if rm is not None:
            command += ['--rm', str(rm)]
        if exact is not None:
            command += ['--exact', str(int(exact))]
        for name, value in zip('abc', operands):
            command += ['--' + name, hex(value)]
        expected = json.loads(subprocess.check_output(command, text=True))
        result_width = 1 if op in ('eq', 'lt', 'lt_quiet', 'le', 'le_quiet') else int(expected['dst'][1:]) if expected['dst'].startswith(('i', 'u', 'f')) else 16
        inputs = []
        if rm is not None:
            inputs.append(f'3:{rm:x}')
        src_width = 16 if fmt == 'f16' else int(fmt[1:])
        inputs += [f'{src_width}:{value:x}' for value in operands]
        if exact is not None:
            inputs.append(f'b:{int(exact)}')
        lines.append(' '.join([helper, str(result_width), expected['flags'],
                               expected['result_bits'], '0', str(len(inputs)), *inputs]))
    probe = subprocess.run([args.probe, args.ir], input='\n'.join(lines) + '\n',
                           text=True, capture_output=True)
    if probe.returncode:
        raise RuntimeError(f'probe failed after {len(probe.stdout.splitlines())}/{len(lines)} cases: {probe.stderr}')
    print(f'PASS {len(lines)} f16 wrapper cases: exact bits and five flags, one path, SAT/UNSAT')


if __name__ == '__main__':
    main()
