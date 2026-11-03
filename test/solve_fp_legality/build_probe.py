#!/usr/bin/env python3
"""Extract the exact old/current V legality functions into one small Sail model."""

import argparse
from hashlib import sha256
import json
from pathlib import Path
import re

TEST = Path(__file__).resolve().parent
MODEL = TEST.parents[1] / "model/extensions/V"
NAMES = ("valid_vtype", "valid_rd_mask", "valid_fp_op", "illegal_fp_normal")


def block(source, name):
    match = re.search(rf"^function {name}\([^\n]*\) -> bool = \{{\n.*?^\}}", source, re.M | re.S)
    assert match, name
    return match.group()


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=Path)
args = parser.parse_args()
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=False)
old_files = {name: (TEST / "before" / name).read_text() for name in
             ("vext_utils_insts.sail", "vext_fp_utils_insts.sail")}
new_files = {name: (MODEL / name).read_text() for name in old_files}
assert all(old_files[name] != new_files[name] for name in old_files)
for name in old_files:
    old = old_files[name]
    new = new_files[name]
    for function in NAMES:
        if f"function {function}(" in old:
            old = old.replace(block(old, function), f"<FUNCTION:{function}>")
            new = new.replace(block(new, function), f"<FUNCTION:{function}>")
    assert old == new, f"unapproved change outside four functions in {name}"

prefix = """default Order dec
$include <prelude.sail>
$include <generic_equality.sail>
val not : forall ('p : Bool). bool('p) -> bool(not('p))
function not(b) = not_bool(b)

val strict_and_bool = pure {c: "strict_and_bool"} : (bool, bool) -> bool
val strict_or_bool = pure {c: "strict_or_bool"} : (bool, bool) -> bool
function strict_and_bool(lhs, rhs) = lhs & rhs
function strict_or_bool(lhs, rhs) = lhs | rhs

newtype vregidx = Vregidx : bits(5)
function vregidx_bits(Vregidx(b) : vregidx) -> bits(5) = b
let zvreg : vregidx = Vregidx(0b00000)
bitfield Vtype : bits(64) = { vill : 63 }
register vtype : Vtype
type sew_bitsize = {8, 16, 32, 64}
"""
parts = [prefix]
for label, files in (("old", old_files), ("new", new_files)):
    for name in NAMES:
        source = files["vext_utils_insts.sail" if name in NAMES[:2]
                       else "vext_fp_utils_insts.sail"]
        body = block(source, name)
        if label == "old":
            body = re.sub(r"\b(?:valid_vtype|valid_rd_mask|valid_fp_op|illegal_fp_normal)\b",
                          lambda m: "old_" + m.group(), body)
        parts.append(body)

for sew in (8, 16, 32, 64):
    parts.append(f"""function proof_sew{sew}() -> (bool, bool, bool, bool, bool, bool, bool, bool, bits(64), bits(64)) = {{
  let vt_bits : bits(64) = undefined;
  let rd_bits : bits(5) = undefined;
  let vm : bits(1) = undefined;
  let rm : bits(3) = undefined;
  let rd = Vregidx(rd_bits);
  vtype.bits = vt_bits;
  let before = vtype.bits;
  let ov = old_valid_vtype();
  let od = old_valid_rd_mask(rd, vm);
  let ofp = old_valid_fp_op({sew}, rm);
  let oi = old_illegal_fp_normal(rd, vm, {sew}, rm);
  let nv = valid_vtype();
  let nd = valid_rd_mask(rd, vm);
  let nfp = valid_fp_op({sew}, rm);
  let ni = illegal_fp_normal(rd, vm, {sew}, rm);
  let after = vtype.bits;
  (ov, od, ofp, oi, nv, nd, nfp, ni, before, after)
}}""")

parts.append("function main() -> unit = ()")

(out / "probe.sail").write_text("\n\n".join(parts) + "\n")
(out / "probe.sail_project").write_text("probe {\n  files probe.sail\n}\n")
manifest = {
    "before": {name: sha256(text.encode()).hexdigest() for name, text in old_files.items()},
    "after": {name: sha256(text.encode()).hexdigest() for name, text in new_files.items()},
    "probe_sha256": sha256((out / "probe.sail").read_bytes()).hexdigest(),
    "proof_functions": [f"proof_sew{sew}" for sew in (8, 16, 32, 64)],
    "inputs": "vtype bits64 arbitrary; vd bits5 arbitrary; vm bits1 arbitrary; rm bits3 arbitrary; SEW exactly 8/16/32/64",
}
(out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
