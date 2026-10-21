#!/usr/bin/env python3
"""Prepare full-state vector reduction cases from the independent oracle suites."""

import argparse
import hashlib
import json
from pathlib import Path


CLAUSES = {"RFVVTYPE", "RFWVVTYPE"}
NUMERIC_PREFIXES = (
    "numeric_rfvvtype_",
    "numeric_rfwvvtype_",
    "numeric_redmin_",
    "numeric_redmax_",
)
GUARD_GROUPS = (
    "baseline",
    "enum-sew",
    "inactive-state",
    "inactive-hazard",
    "vs-dirty-state",
    "legal-mf4",
    "legal-policy",
    "legal-lmul",
)


def read_cases(path):
    rows = json.loads(path.read_text())
    assert isinstance(rows, list), path
    return rows


def full_vector_state(row):
    """Make every physical vector register and available CSR observable."""
    row = json.loads(json.dumps(row))
    initial = row["initial"]
    expected = row["expected"]
    for index in range(32):
        name = f"vr{index}"
        initial.setdefault(name, "0x0")
        expected.setdefault(name, initial[name])
    for name in ("vtype", "vl", "vstart", "fcsr", "mstatus", "misa", "f1", "f3"):
        if name in initial:
            expected.setdefault(name, initial[name])
    row["observe"] = list(dict.fromkeys([*row["observe"], *expected]))
    return row


def masked_inactive_snan(numeric):
    """An inactive sNaN precedes an active exact cancellation lane."""
    rows = []
    for clause, mnemonic in (("RFVVTYPE", "vfredosum"),
                             ("RFWVVTYPE", "vfwredosum")):
        stem = f"numeric_{clause.lower()}_fvv_{mnemonic}"
        masked = next(row for row in numeric if row["name"] == f"{stem}_mask_lane1")
        forward = next(row for row in numeric if row["name"] == f"{stem}_forward")
        row = json.loads(json.dumps(masked))
        row["name"] = f"reduction_{clause.lower()}_inactive_snan_then_active"
        row["case_id"] = int.from_bytes(hashlib.sha256(row["name"].encode()).digest()[:8], "big")
        row["initial"]["vr0"] = "0x2"  # only the second source lane is active
        source = int(row["initial"]["vr2"], 16)
        row["initial"]["vr2"] = hex((source & ~0xFFFFFFFF) | 0x7F800001)
        row["expected"]["vr3"] = forward["expected"]["vr3"]
        row["expected"]["fcsr"] = row["initial"]["fcsr"]
        rows.append(row)
    return rows


def zero_vl_illegal_start(illegal):
    rows = []
    for source in illegal:
        row = json.loads(json.dumps(source))
        row["name"] = f"{source['name']}_vl0"
        row["case_id"] = int.from_bytes(hashlib.sha256(row["name"].encode()).digest()[:8], "big")
        row["initial"]["vl"] = "0x0"
        row["expected"]["vl"] = "0x0"
        rows.append(row)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--numeric", type=Path, required=True)
    parser.add_argument("--hazards", type=Path, required=True)
    parser.add_argument("--guards", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    numeric = [row for row in read_cases(args.numeric)
               if row["clause"] in CLAUSES and row["name"].startswith(NUMERIC_PREFIXES)]
    hazards = read_cases(args.hazards)
    guards = [row for group in GUARD_GROUPS
              for row in read_cases(args.guards / f"{group}.json")
              if row["clause"] in CLAUSES]
    illegal = read_cases(args.guards / "illegal-red-start.json")
    assert len(numeric) == 52, len(numeric)
    assert len(hazards) == 40, len(hazards)
    assert len(guards) == 48, len(guards)
    assert len(illegal) == 2, len(illegal)
    new_hazards = masked_inactive_snan(numeric)
    rows = [full_vector_state(row) for row in [*numeric, *hazards, *guards, *new_hazards]]
    names = [row["name"] for row in rows]
    assert len(names) == len(set(names)), "duplicate input names"
    assert all(row.get("case_id") == int.from_bytes(
        hashlib.sha256(row["name"].encode()).digest()[:8], "big") for row in rows)
    assert len({row["case_id"] for row in rows}) == len(rows)
    assert all(row["clause"] in CLAUSES for row in rows)
    assert any("forward" in name for name in names)
    assert any("reverse" in name for name in names)
    assert any("allmask_snan_seed" in name for name in names)
    assert any("vl0_state" in name for name in names)
    assert any("masked_snan_suppressed" in name for name in names)
    assert any("VS_Clean_write" in name for name in names)

    output = args.output / "reduction-cases.json"
    output.write_text(json.dumps(rows, indent=2) + "\n")
    illegal_output = args.output / "reduction-illegal.json"
    illegal_rows = [full_vector_state(row) for row in [*illegal, *zero_vl_illegal_start(illegal)]]
    assert len({row["case_id"] for row in illegal_rows}) == len(illegal_rows)
    assert all(row["case_id"] == int.from_bytes(
        hashlib.sha256(row["name"].encode()).digest()[:8], "big") for row in illegal_rows)
    illegal_output.write_text(json.dumps(illegal_rows, indent=2) + "\n")
    manifest = {
        "cases": len(rows),
        "numeric": len(numeric),
        "hazards": len(hazards),
        "guards": len(guards),
        "new_hazards": len(new_hazards),
        "illegal": len(illegal_rows),
        "input_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "illegal_sha256": hashlib.sha256(illegal_output.read_bytes()).hexdigest(),
        "sources": {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                    for path in (args.numeric, args.hazards)},
    }
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest))


if __name__ == "__main__":
    main()
