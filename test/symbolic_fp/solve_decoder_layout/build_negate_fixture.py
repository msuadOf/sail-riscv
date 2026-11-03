#!/usr/bin/env python3
"""Build a small old/new negate model from frozen real source files."""

import argparse
import re
from pathlib import Path


def extract(source: str, name: str) -> str:
    match = re.search(rf"^function {name}\([^\n]*?(?:\n[^\n]*)*?\n}}", source, re.M)
    assert match, name
    return match.group()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    parts = [
        "default Order dec",
        "$include <prelude.sail>",
        "overload operator ^ = {xor_vec}",
    ]
    for width, filename, size in (("H", "zfh_insts.sail", 16),
                                  ("S", "fext_insts.sail", 32),
                                  ("D", "dext_insts.sail", 64)):
        source = (args.source_dir / filename).read_text()
        for stem in ("fsplit", "fmake"):
            block = re.search(rf"^function {stem}_{width}\([^\n]*\n  [^\n]*", source, re.M)
            assert block, (stem, width)
            parts.append(block.group())
        old = extract(source, f"negate_{width}")
        assert old.count("let new_sign = if (sign == 0b0) then 0b1 else 0b0;") == 1
        parts.append(old.replace(f"negate_{width}", f"old_negate_{width}"))
        parts.append(old.replace(f"negate_{width}", f"new_negate_{width}")
                     .replace("let new_sign = if (sign == 0b0) then 0b1 else 0b0;",
                              "let new_sign = sign ^ 0b1;"))
        parts.append(f"function equal_{width}(x : bits({size})) -> bool = "
                     f"old_negate_{width}(x) == new_negate_{width}(x)")
        parts.append(f"function raw_flip_{width}(x : bits({size})) -> bool = "
                     f"new_negate_{width}(x) == (x ^ 0x{1 << (size - 1):0{size // 4}x})")
    args.output.write_text("\n\n".join(parts) + "\n")


if __name__ == "__main__":
    main()
