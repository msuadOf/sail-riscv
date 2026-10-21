#!/usr/bin/env python3
"""Extract the actual pre-edit scalar min/max value paths into a small Sail model."""

from hashlib import sha256
import json
from pathlib import Path
import re
import struct
import sys

output = Path(sys.argv[1]).resolve()
snapshot = Path(sys.argv[2]).resolve()
model = Path(__file__).resolve().parents[3] / "model"
output.mkdir(parents=True, exist_ok=False)
(output / "model").symlink_to(model, target_is_directory=True)


def old_file(name):
    path = snapshot / "pre-edit/sail-riscv/model/extensions/FD" / name
    return path.read_text()


def function(source, name):
    match = re.search(rf"^function {name}\([^\n]*", source, re.M)
    assert match, name
    start = match.start()
    line_end = source.index("\n", start)
    first = source[start:line_end]
    if first.rstrip().endswith("= {"):
        end = source.index("\n}", line_end) + 2
    else:
        end = source.index("\n\n", line_end)
    return source[start:end] + "\n\n"


sources = {"H": old_file("zfh_insts.sail"),
           "S": old_file("fext_insts.sail"),
           "D": old_file("dext_insts.sail")}
source = """// Generated from the pre-edit source snapshot by build_probe.py.
// The old classifiers, splitters, fle and twelve value bodies are verbatim.
function nvFlag() -> bits(5) = 0b_10000
"""
fd_regs = (model / "extensions/FD/fdext_regs.sail").read_text()
start = fd_regs.index("val canonical_NaN :")
end = fd_regs.index("// n-bit writes", start)
source += fd_regs[start:end].replace("let canonical_NaN_BF16 : bits(16) = 0x7fc0\n", "")
for width in "HSD":
    original = sources[width]
    for name in ("fsplit", "f_is_neg_zero", "f_is_pos_zero", "f_is_SNaN", "f_is_NaN", "fle"):
        source += function(original, f"{name}_{width}")

entries = []
wrappers = ""


def directed_pairs(size):
    exp_bits, mant_bits = {16: (5, 10), 32: (8, 23), 64: (11, 52)}[size]
    sign = 1 << (size - 1)
    inf = ((1 << exp_bits) - 1) << mant_bits
    quiet = 1 << (mant_bits - 1)
    one = {16: 0x3c00, 32: 0x3f800000, 64: 0x3ff0000000000000}[size]
    two = {16: 0x4000, 32: 0x40000000, 64: 0x4000000000000000}[size]
    qnan = inf | quiet | 1
    snan = inf | 1
    return [
        (qnan, one), (one, qnan), (sign | qnan, one), (one, sign | qnan),
        (snan, two), (two, snan), (sign | snan, two), (two, sign | snan),
        (qnan, qnan | 2), (qnan, snan), (snan, sign | snan),
        (0, sign), (sign, 0), (0, 0), (sign, sign),
        (one, one), (one, two), (two, one),
        (inf, one), (sign | inf, one), (inf, sign | inf),
        (1, one), (sign | 1, one), (1, sign | 1),
    ]


def expected(size, operation, a, b):
    exp_bits, mant_bits = {16: (5, 10), 32: (8, 23), 64: (11, 52)}[size]
    inf = ((1 << exp_bits) - 1) << mant_bits
    sign = 1 << (size - 1)
    def nan(x):
        return x & inf == inf and x & ((1 << mant_bits) - 1) != 0
    def snan(x):
        return nan(x) and x & (1 << (mant_bits - 1)) == 0
    flags = 0x10 if snan(a) or snan(b) else 0
    canonical = inf | (1 << (mant_bits - 1))
    if nan(a) or nan(b):
        if operation.endswith("M") or nan(a) and nan(b):
            return flags, canonical
        return flags, b if nan(a) else a
    if a & ~sign == 0 and b & ~sign == 0:
        return flags, a | b if operation.startswith("FMIN") else a & b
    fmt = {16: ">e", 32: ">f", 64: ">d"}[size]
    to_float = lambda x: struct.unpack(fmt, x.to_bytes(size // 8, "big"))[0]
    va, vb = to_float(a), to_float(b)
    if operation.startswith("FMIN"):
        return flags, a if va <= vb else b
    return flags, a if va >= vb else b


for width, size in (("H", 16), ("S", 32), ("D", 64)):
    for operation in ("FMIN", "FMAX", "FMINM", "FMAXM"):
        old = old_file("zfa_insts.sail") if operation.endswith("M") else sources[width]
        pattern = rf"^function clause execute [^\n]*\b{operation}_{width}\b[^\n]* = \{{\n.*?\n\}}"
        match = re.search(pattern, old, re.M | re.S)
        assert match, (operation, width)
        block = match.group()
        body = block[block.index("  let is_quiet  = true;"):block.index("  accrue_fflags(fflags);")]
        assert body.count(f"fle_{width}") == 1
        key = f"{operation.lower()}_{width.lower()}"
        old_name = f"old_{key}"
        helper = {"FMIN": "fp_min_pure", "FMAX": "fp_max_pure",
                  "FMINM": "fp_minm_pure", "FMAXM": "fp_maxm_pure"}[operation]
        source += f"""function {old_name}(a : bits({size}), b : bits({size})) -> (bits_fflags, bits({size})) = {{
  let rs1_val_{width} = a;
  let rs2_val_{width} = b;
{body}  (fflags, rd_val_{width})
}}
"""

        wrappers += f"""function eq_{key}() -> bool = {{
  let a : bits({size}) = undefined;
  let b : bits({size}) = undefined;
  let (old_flags, old_bits) = {old_name}(a, b);
  let (new_flags, new_bits) = {helper}(a, b);
  strict_and_bool(old_flags == new_flags, old_bits == new_bits)
}}

function new_{key}() -> (bits_fflags, bits({size})) = {{
  let a : bits({size}) = undefined;
  let b : bits({size}) = undefined;
  {helper}(a, b)
}}

"""
        entries += [f"eq_{key}", f"new_{key}"]
        wrappers += f"function directed_{key}() -> bool = {{\n  var ok : bool = true;\n"
        for index, (a, b) in enumerate(directed_pairs(size)):
            flags, bits = expected(size, operation, a, b)
            hexchars = size // 4
            wrappers += f"""  let (old_f_{index}, old_v_{index}) = {old_name}(0x{a:0{hexchars}x}, 0x{b:0{hexchars}x});
  let (new_f_{index}, new_v_{index}) = {helper}(0x{a:0{hexchars}x}, 0x{b:0{hexchars}x});
  ok = strict_and_bool(ok, old_f_{index} == 0b{flags:05b});
  ok = strict_and_bool(ok, new_f_{index} == 0b{flags:05b});
  ok = strict_and_bool(ok, old_v_{index} == 0x{bits:0{hexchars}x});
  ok = strict_and_bool(ok, new_v_{index} == 0x{bits:0{hexchars}x});
"""
        wrappers += "  ok\n}\n\n"
        entries.append(f"directed_{key}")

(output / "probe_defs.sail").write_text(source)
(output / "probe.sail").write_text(wrappers)
(output / "names.txt").write_text("\n".join(entries) + "\n")
(output / "probe.sail_project").write_text("""prelude {
  files model/prelude/prelude.sail, model/prelude/ieee_fp_primops.sail,
}
core {
  requires prelude
  files model/core/softfloat_interface.sail, model/core/float_classify.sail,
    model/core/ieee_fp_exceptions.sail,
}
probe {
  requires prelude, core
  files model/extensions/FD/softfloat_symbolic.sail,
    model/extensions/FD/softfloat_symbolic_f16.sail,
    model/extensions/FD/softfloat_symbolic_f32.sail,
    model/extensions/FD/softfloat_symbolic_f64.sail,
    probe_defs.sail,
    model/extensions/FD/fp_minmax.sail,
    probe.sail,
}
""")
manifest = {"old_source": {name: sha256(old_file(name).encode()).hexdigest()
                           for name in ("fext_insts.sail", "dext_insts.sail",
                                        "zfh_insts.sail", "zfa_insts.sail")},
            "probe_defs_sha256": sha256(source.encode()).hexdigest(),
            "probe_sha256": sha256(wrappers.encode()).hexdigest(),
            "entries": entries}
(output / "fixture-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
