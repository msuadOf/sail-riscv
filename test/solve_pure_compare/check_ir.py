#!/usr/bin/env python3
"""确保新分类调用闭包不使用主动查询的位串比较；位宽分支仍允许。"""

import argparse
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("ir", type=Path)
parser.add_argument("--prefix", default="")
args = parser.parse_args()
source = args.ir.read_text()
bodies = dict(re.findall(r"^fn (\w+)\([^\n]*\) \{\n(.*?)^\}", source, re.M | re.S))
seen = set()
pending = ["z" + args.prefix + "ieee_is_" + name for name in ["nan", "snan", "inf", "zzero", "finite"]]
while pending:
    name = pending.pop()
    if name in seen:
        continue
    seen.add(name)
    assert name in bodies, f"missing function body: {name}"
    calls = re.findall(r"\b(z\w+)\(", bodies[name])
    assert not any(call in {"zeq_bits", "zneq_bits"} for call in calls), f"active bit equality reachable in {name}"
    pending.extend(call for call in calls if call in bodies)
assert any("zeq_anything" in bodies[name] for name in seen), "generic equality was not preserved"
print(f"classification closure: {len(seen)} functions, generic equality preserved, no eq_bits/neq_bits")
for width in (16, 32, 64):
    names = [f"z{args.prefix}ieee_{operation}{width}_exceptions" for operation in ["add", "sub", "sqrt", "fma"]]
    names += [f"z{args.prefix}riscv_f{width}{operation}" for operation in ["ToI32", "ToUi32", "ToI64", "ToUi64"]]
    for name in names:
        assert name in bodies, f"missing function body: {name}"
        assert not re.search(r"\b(?:zeq_bits|zneq_bits|zeq_bool|zneq_bool|jump|goto)\b", bodies[name]), f"active data comparison or branch in {name}"
print("24 arithmetic-sign/integer-saturation bodies: no active data comparison or branch")
