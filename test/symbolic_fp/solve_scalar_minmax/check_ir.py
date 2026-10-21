#!/usr/bin/env python3
"""Check specialized equality and identify only the width-dispatch jumps."""

from pathlib import Path
import re
import sys

ir = Path(sys.argv[1]).read_text()
for name in ("fp_min_pure", "fp_max_pure", "fp_minm_pure", "fp_maxm_pure"):
    match = re.search(rf"^fn z{name}\([^\n]*", ir, re.M)
    assert match, f"missing {name}"
    next_fn = re.search(r"^fn ", ir[match.end():], re.M)
    body = ir[match.start():match.end() + next_fn.start()] if next_fn else ir[match.start():]
    assert "zeq_bits(" not in body and "zneq_bits(" not in body, name
    jumps = re.findall(r"^\s*jump\s+@not\((zz\d+)\)\s+goto\s+\d+", body, re.M)
    all_jumps = re.findall(r"^\s*jump\s+.*$", body, re.M)
    assert len(jumps) == len(all_jumps), f"{name}: unexpected jump form"
    expected_widths = {16, 32} if name in ("fp_min_pure", "fp_max_pure") else set()
    found_widths = set()
    assignments = {}
    for target, expression in re.findall(r"^\s*(zz\d+) = ([^`\n]+)", body, re.M):
        assignments.setdefault(target, []).append(expression.strip())

    def from_op2_width(symbol, visited=None):
        visited = set() if visited is None else visited
        assert symbol not in visited, f"{name}: cycle in width source {symbol}"
        visited.add(symbol)
        expressions = assignments.get(symbol, [])
        assert len(expressions) == 1, f"{name}: ambiguous width source {symbol}"
        expression = expressions[0]
        if expression == "zbitvector_length(zop2)":
            return True
        alias = re.fullmatch(r"zz\d+", expression)
        cast = re.fullmatch(r"zz5(?:izDzKz5i64|i64zDzKz5i)\((zz\d+)\)", expression)
        if alias:
            return from_op2_width(expression, visited)
        if cast:
            return from_op2_width(cast.group(1), visited)
        raise AssertionError(f"{name}: non-width expression {expression} for {symbol}")

    for predicate in jumps:
        eq = re.search(rf"^\s*{predicate} = zeq_int\((zz\d+), (zz\d+)\)", body, re.M)
        assert eq, f"{name}: non-width jump predicate {predicate}"
        assert from_op2_width(eq.group(1)), f"{name}: left operand is not op2 width"
        constant = re.search(rf"^\s*{eq.group(2)} = zz5i64zDzKz5i\((16|32)\)", body, re.M)
        assert constant, f"{name}: non-width jump constant {predicate}"
        found_widths.add(int(constant.group(1)))
    assert found_widths == expected_widths, f"{name}: width dispatch {found_widths}"
    print(f"PASS {name}: no eq_bits/neq_bits; width jumps={len(jumps)}, data jumps=0")
