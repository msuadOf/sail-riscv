#!/usr/bin/env python3
"""Build a small IR fixture from the production pure helpers and legacy bodies."""

import pathlib
import sys

out = pathlib.Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=True)
model = pathlib.Path(__file__).resolve().parents[3] / "model"
(out / "model").symlink_to(model, target_is_directory=True) if not (out / "model").exists() else None
utils = (model / "extensions/V/vext_fp_utils_insts.sail").read_text()
fd_minmax = (model / "extensions/FD/fp_minmax.sail").read_text()


def definition(name: str, following: str, old: bool = False) -> str:
    source = fd_minmax if not old and name in ("min_pure", "max_pure") else utils
    marker = source.index("$endif", source.index("val fp_add_pure")) if old else 0
    begin = source.index(f"val fp_{name}", marker)
    end_name = "val fp_minm_pure" if name == "max_pure" and not old else f"val fp_{following}"
    end = source.index(end_name, begin)
    body = source[begin:end]
    if old:
        body = body.replace(f"fp_{name}", f"old_fp_{name}")
        body = body.replace("  accrue_fflags(fflags);\n", "")
        body = body.replace("  result_val\n}", "  (fflags, result_val)\n}")
        body = body.replace("-> bits('m)", "-> (bits_fflags, bits('m))")
        body = body.replace("-> bool", "-> (bits_fflags, bool)")
    return body


source = """// Generated from the current production V helpers by build_helper_probe.py.
val canonical_NaN : forall 'n, 'n in {16, 32, 64, 128}. implicit('n) -> bits('n)
function canonical_NaN(n) = match 'n {
  16 => 0x7e00, 32 => 0x7fc00000,
  64 => 0x7ff8000000000000, 128 => 0b0 @ ones(15) @ 0b1 @ zeros(111)
}
val f_is_NaN : forall 'm, 'm in {16,32,64}. bits('m) -> bool
function f_is_NaN(x) = ieee_is_nan(x)
val f_is_neg_zero : forall 'm, 'm in {16,32,64}. bits('m) -> bool
function f_is_neg_zero(x) = x == 0b1 @ zeros('m - 1)
val f_is_pos_zero : forall 'm, 'm in {16,32,64}. bits('m) -> bool
function f_is_pos_zero(x) = x == zeros('m)
function nvFlag() -> bits(5) = 0b10000
"""
for name, following in (("min_pure", "max_pure"), ("max_pure", "eq_pure"),
                        ("eq_pure", "ne_pure"), ("ne_pure", "lt_pure"),
                        ("lt_pure", "le_pure"), ("le_pure", "gt_pure"),
                        ("gt_pure", "ge_pure"), ("ge_pure", "widen_pure")):
    source += definition(name, following)
for name, following in (("min", "max"), ("max", "eq"),
                        ("gt", "ge"), ("ge", "lt")):
    source += definition(name, following, old=True)
class_begin = utils.index("val fp_class_onehot_pure")
source += utils[class_begin:utils.index("$endif", class_begin)]
narrow_begin = utils.index("function riscv_f16ToI16(")
source += utils[narrow_begin:utils.index("$ifdef SYMBOLIC", narrow_begin)]
narrow_pure_begin = utils.index("function riscv_f16ToI16_pure(")
source += utils[narrow_pure_begin:utils.index("$endif", narrow_pure_begin)]

source += """
function eq_min_unknown() -> bool = {
  let a : bits(16) = undefined;
  let b : bits(16) = undefined;
  let (af, av) = old_fp_min(a, b);
  let (bf, bv) = fp_min_pure(a, b);
  strict_and_bool(af == bf, av == bv)
}
function eq_max_unknown() -> bool = {
  let a : bits(16) = undefined;
  let b : bits(16) = undefined;
  let (af, av) = old_fp_max(a, b);
  let (bf, bv) = fp_max_pure(a, b);
  strict_and_bool(af == bf, av == bv)
}
function eq_gt_unknown() -> bool = {
  let a : bits(16) = undefined;
  let b : bits(16) = undefined;
  let (af, av) = old_fp_gt(a, b);
  let (bf, bv) = fp_gt_pure(a, b);
  strict_and_bool(af == bf, av == bv)
}
function eq_ge_unknown() -> bool = {
  let a : bits(16) = undefined;
  let b : bits(16) = undefined;
  let (af, av) = old_fp_ge(a, b);
  let (bf, bv) = fp_ge_pure(a, b);
  strict_and_bool(af == bf, av == bv)
}
function new_min_unknown() -> (bits_fflags, bits(16)) = {
  let a : bits(16) = undefined;
  let b : bits(16) = undefined;
  fp_min_pure(a, b)
}
function new_max_unknown() -> (bits_fflags, bits(16)) = {
  let a : bits(16) = undefined;
  let b : bits(16) = undefined;
  fp_max_pure(a, b)
}
function new_gt_unknown() -> (bits_fflags, bool) = {
  let a : bits(16) = undefined;
  let b : bits(16) = undefined;
  fp_gt_pure(a, b)
}
function new_ge_unknown() -> (bits_fflags, bool) = {
  let a : bits(16) = undefined;
  let b : bits(16) = undefined;
  fp_ge_pure(a, b)
}
function directed_cases() -> bool = {
  let (min_zeros_f, min_zeros) = fp_min_pure(0x0000, 0x8000);
  let (max_zeros_f, max_zeros) = fp_max_pure(0x0000, 0x8000);
  let (min_qnan_f, min_qnan) = fp_min_pure(0x7e01, 0x3c00);
  let (max_qnan_f, max_qnan) = fp_max_pure(0x7e01, 0x3c00);
  let (min_two_nan_f, min_two_nan) = fp_min_pure(0x7e01, 0x7e02);
  let (min_snan_f, min_snan) = fp_min_pure(0x7c01, 0x3c00);
  let (gt_nan_f, gt_nan) = fp_gt_pure(0x7e01, 0x3c00);
  let (ge_nan_f, ge_nan) = fp_ge_pure(0x7e01, 0x3c00);
  var ok = min_zeros == 0x8000;
  ok = strict_and_bool(ok, min_zeros_f == 0b00000);
  ok = strict_and_bool(ok, max_zeros == 0x0000);
  ok = strict_and_bool(ok, max_zeros_f == 0b00000);
  ok = strict_and_bool(ok, min_qnan == 0x3c00);
  ok = strict_and_bool(ok, min_qnan_f == 0b00000);
  ok = strict_and_bool(ok, max_qnan == 0x3c00);
  ok = strict_and_bool(ok, max_qnan_f == 0b00000);
  ok = strict_and_bool(ok, min_two_nan == 0x7e00);
  ok = strict_and_bool(ok, min_two_nan_f == 0b00000);
  ok = strict_and_bool(ok, min_snan == 0x3c00);
  ok = strict_and_bool(ok, min_snan_f == 0b10000);
  ok = strict_and_bool(ok, gt_nan_f == 0b10000);
  ok = strict_and_bool(ok, ge_nan_f == 0b10000);
  ok = strict_and_bool(ok, not_bool(gt_nan));
  strict_and_bool(ok, not_bool(ge_nan))
}
function eq_directed_cases() -> bool = directed_cases()
"""

for width in (32, 64):
    for operation in ("min", "max", "gt", "ge"):
        result_type = f"bits({width})" if operation in ("min", "max") else "bool"
        source += f"""function eq_{operation}_unknown{width}() -> bool = {{
  let a : bits({width}) = undefined;
  let b : bits({width}) = undefined;
  let (af, av) = old_fp_{operation}(a, b);
  let (bf, bv) = fp_{operation}_pure(a, b);
  strict_and_bool(af == bf, av == bv)
}}
function new_{operation}_unknown{width}() -> (bits_fflags, {result_type}) = {{
  let a : bits({width}) = undefined;
  let b : bits({width}) = undefined;
  fp_{operation}_pure(a, b)
}}
"""

directed_class = {
    16: ("fc00", "bc00", "8001", "8000", "0000", "0001", "3c00", "7c00", "7c01", "7e00"),
    32: ("ff800000", "bf800000", "80000001", "80000000", "00000000", "00000001", "3f800000", "7f800000", "7f800001", "7fc00000"),
    64: ("fff0000000000000", "bff0000000000000", "8000000000000001", "8000000000000000", "0000000000000000", "0000000000000001", "3ff0000000000000", "7ff0000000000000", "7ff0000000000001", "7ff8000000000000"),
}
for width, values in directed_class.items():
    source += f"""function eq_class_unknown{width}() -> bool = {{
  let raw : bits({width}) = undefined;
  float_class_onehot_bits(float_classify(raw)) == fp_class_onehot_pure(raw)
}}
function new_class_unknown{width}() -> bits(10) = {{
  let raw : bits({width}) = undefined;
  fp_class_onehot_pure(raw)
}}
function eq_class_onehot{width}() -> bool = {{
  let raw : bits({width}) = undefined;
  let classified = fp_class_onehot_pure(raw);
  strict_and_bool(classified != 0b0000000000,
    (classified & (classified - 0b0000000001)) == 0b0000000000)
}}
function eq_class_directed{width}() -> bool = {{
  var ok : bool = true;
"""
    for bit, value in enumerate(values):
        source += f"  ok = strict_and_bool(ok, fp_class_onehot_pure(0x{value}) == to_bits_unsafe(10, {1 << bit}));\n"
    source += "  ok\n}\n"

for name, source_width in (("riscv_f16ToI16", 16), ("riscv_f16ToI8", 16),
                           ("riscv_f32ToI16", 32), ("riscv_f16ToUi16", 16),
                           ("riscv_f16ToUi8", 16), ("riscv_f32ToUi16", 32)):
    source += f"""function eq_{name}_unknown() -> bool = {{
  let raw : bits({source_width}) = undefined;
  let (af, av) = {name}(0b011, raw);
  let (bf, bv) = {name}_pure(0b011, raw);
  strict_and_bool(af == bf, av == bv)
}}
function new_{name}_unknown() -> (bits_fflags, bits({8 if name.endswith('I8') or name.endswith('Ui8') else 16})) = {{
  let raw : bits({source_width}) = undefined;
  {name}_pure(0b011, raw)
}}
"""

(out / "helper_probe.sail").write_text(source)
(out / "helper_probe.sail_project").write_text(f"""prelude {{
  files model/prelude/prelude.sail, model/prelude/ieee_fp_primops.sail,
}}
core {{
  requires prelude
  files model/core/softfloat_interface.sail, model/core/float_classify.sail,
    model/core/ieee_fp_exceptions.sail,
}}
probe {{
  requires prelude, core
  files model/extensions/FD/softfloat_symbolic.sail,
    model/extensions/FD/softfloat_symbolic_f16.sail,
    model/extensions/FD/softfloat_symbolic_f32.sail,
    model/extensions/FD/softfloat_symbolic_f64.sail,
    helper_probe.sail,
}}
""")
