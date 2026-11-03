#!/usr/bin/env python3
"""Check that the new AMO format matcher does not branch into partial mappings."""

import argparse
import json
import re
from pathlib import Path


def functions(ir: str) -> dict[str, str]:
    return {name: body for name, body in re.findall(r"(?ms)^fn (\w+)\([^\n]*\) \{\n(.*?)^\}", ir)}


def inspect(path: Path) -> dict:
    bodies = functions(path.read_text())
    old = bodies["zencdec_amoop_backwards_matches"]
    new = bodies["zamo_layout_backwards_matches"]
    top = bodies["znew_top_backwards_matches"]
    helpers = ["zamo_layout_op_matches", "zamo_layout_width_matches", "zamo_layout_reg_matches"]
    assert "zamo_layout_backwards_matches(" in top
    assert "zencdec_amoop_backwards_matches(" not in new
    assert "zamo_layout_op_matches(" in new
    assert "zamo_layout_width_matches(" in new
    assert new.count("zamo_layout_reg_matches(") == 3
    for name in helpers + ["zamo_layout_backwards_matches"]:
        assert "jump " not in bodies[name], name
    assert old.count("jump ") >= 10, "red baseline unexpectedly absent"
    return {
        "path": str(path),
        "old_op_matcher": {"jump": old.count("jump "), "eq_bits": old.count("zeq_bits(")},
        "new_full_matcher": {"jump": new.count("jump "), "eq_bits": new.count("zeq_bits(")},
        "new_helper_jumps": {name: bodies[name].count("jump ") for name in helpers},
        "top_calls_new_matcher": True,
        "new_matcher_calls_old_op_matcher": False,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("ir", nargs="+", type=Path)
    args = parser.parse_args()
    print(json.dumps([inspect(path) for path in args.ir], indent=2))


if __name__ == "__main__":
    main()
