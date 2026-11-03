#!/usr/bin/env python3
"""Check the ordinary clauses and the migrated V definitions against frozen bytes."""

from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[3]
snapshot = Path(sys.argv[1]).resolve() / "pre-edit" / "sail-riscv/model"
model = root / "model"
clause = re.compile(
    r"\$ifdef SYMBOLIC\n(function clause execute [^\n]*\bF(?:MIN|MAX)M?_[HSD]\b[^\n]* = \{\n.*?\n\})"
    r"\n\$else\n(function clause execute [^\n]*\bF(?:MIN|MAX)M?_[HSD]\b[^\n]* = \{\n.*?\n\})"
    r"\n\$endif", re.S)
for filename, count in (("fext_insts.sail", 2), ("dext_insts.sail", 2),
                        ("zfh_insts.sail", 2), ("zfa_insts.sail", 6)):
    path = Path("extensions/FD") / filename
    original = (snapshot / path).read_text()
    current = (model / path).read_text()
    matches = list(clause.finditer(current))
    assert len(matches) == count, (filename, len(matches))
    for match in matches:
        symbolic, ordinary = match.groups()
        assert symbolic.splitlines()[0] == ordinary.splitlines()[0]
        prefix = ordinary[:ordinary.index("  let is_quiet  = true;")]
        suffix = ordinary[ordinary.index("  accrue_fflags(fflags);"):]
        assert symbolic.startswith(prefix), filename
        assert symbolic.endswith(suffix), filename
        assert len(re.findall(r"= fp_(?:min|max|minm|maxm)_pure\(", symbolic)) == 1
    restored = clause.sub(lambda match: match.group(2), current)
    assert restored == original, f"ordinary source changed: {filename}"
    print(f"PASS {filename}: {count} unchanged ordinary clauses and matching read/write tails")

old_v = (snapshot / "extensions/V/vext_fp_utils_insts.sail").read_text()
new_v = (model / "extensions/V/vext_fp_utils_insts.sail").read_text()
old_chunk = old_v[old_v.index("val fp_min_pure :"):old_v.index("val fp_eq_pure :")]
new_fd = (model / "extensions/FD/fp_minmax.sail").read_text()
assert new_fd.startswith("$ifdef SYMBOLIC\n" + old_chunk)
assert old_v.replace(old_chunk, "") == new_v
print("PASS V min/max pure definitions migrated byte for byte")
