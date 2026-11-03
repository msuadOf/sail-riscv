#!/usr/bin/env python3
"""Require complete SAT/equivalence coverage and one path for new forms."""

import pathlib
import re
import sys

names = pathlib.Path(sys.argv[1]).read_text().splitlines()
log = pathlib.Path(sys.argv[2]).read_text()
for name in names:
    rows = re.findall(rf"^PASS {re.escape(name)} paths=(\d+) all_sat=1 equivalence=(true|false)$", log, re.M)
    assert len(rows) == 1, f"{name}: missing or duplicate result"
    paths, equivalent = rows[0]
    if name.startswith(("new_", "probe_new_")):
        assert paths == "1", f"{name}: expected one path, got {paths}"
    if name.startswith("eq_"):
        assert equivalent == "true", f"{name}: no equality proof"
print(f"validated {len(names)} probe results")
