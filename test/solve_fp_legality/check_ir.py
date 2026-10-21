#!/usr/bin/env python3
"""Require the four V legality helpers' reachable IR to be straight-line Bool code."""

import argparse
import json
from pathlib import Path
import re

ROOTS = ("zvalid_vtype", "zvalid_rd_mask", "zvalid_fp_op", "zillegal_fp_normal")
CALL = re.compile(r"\b(z[A-Za-z0-9_]+)\(")
BODY = re.compile(r"^fn (\w+)\([^\n]*\) \{\n(.*?)^\}", re.M | re.S)

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("ir", type=Path)
parser.add_argument("--report", type=Path)
args = parser.parse_args()
bodies = dict(BODY.findall(args.ir.read_text()))
assert all(name in bodies for name in ROOTS), "missing legality body"
visited = set()
pending = list(ROOTS)
violations = []
while pending:
    name = pending.pop()
    if name in visited:
        continue
    visited.add(name)
    body = bodies[name]
    for line in body.splitlines():
        if re.match(r"\s*(?:jump|goto)\b", line):
            violations.append({"function": name, "kind": "control_flow", "line": line.strip()})
        if any(call in {"zeq_bits", "zneq_bits"} for call in CALL.findall(line)):
            violations.append({"function": name, "kind": "active_bit_equality", "line": line.strip()})
    pending.extend(call for call in CALL.findall(body) if call in bodies)
result = {"roots": ROOTS, "closure": sorted(visited), "violations": violations,
          "status": "PASS" if not violations else "FAIL"}
if args.report:
    args.report.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({"status": result["status"], "closure": len(visited),
                  "violations": len(violations)}))
assert not violations, violations[:8]
