#!/usr/bin/env python3
"""从实际生产文件生成旧新比较探针；旧快照必须在修改生产文件前冻结。"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
FILES = ["model/core/ieee_fp_exceptions.sail"] + [
    f"model/extensions/FD/softfloat_symbolic_f{width}.sail" for width in (16, 32, 64)
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("old", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    old = {name: (args.old / name).read_text() for name in FILES}
    new = {name: (ROOT / name).read_text() for name in FILES}
    names = set(re.findall(r"^(?:function|val) (\w+)", "\n".join(old.values()), re.M))
    names_pattern = re.compile(r"\b(" + "|".join(sorted(names, key=len, reverse=True)) + r")\b")
    manifest = {}
    for label, sources in [("old", old), ("new", new)]:
        manifest[label] = {}
        for name, source in sources.items():
            manifest[label][name] = hashlib.sha256(source.encode()).hexdigest()
            if label == "old":
                source = re.sub(r"struct ieee_fp_exceptions = \{.*?\n\}", "", source, flags=re.S)
                source = names_pattern.sub(lambda match: "audit_old_" + match[0], source)
            (args.output / f"{label}_{Path(name).name}").write_text(source)
    # 依赖也冻结，避免并行修改公共文件改变一次比较的两边。
    for name in ["prelude/prelude.sail", "prelude/ieee_fp_primops.sail", "core/softfloat_interface.sail", "extensions/FD/softfloat_symbolic.sail"]:
        source = ROOT / "model" / name
        shutil.copyfile(source, args.output / source.name)
        manifest[name] = hashlib.sha256(source.read_bytes()).hexdigest()
    probes = ["$ifdef SYMBOLIC"]
    functions = []
    for width in (16, 32, 64):
        name = f"pure_compare_classify{width}"
        functions.append(name)
        fields = ["nan", "snan", "inf", "zero", "finite"]
        old_result = " @ ".join(f"isla_bool_to_bit(audit_old_ieee_is_{field}(a))" for field in fields)
        new_result = " @ ".join(f"isla_bool_to_bit(ieee_is_{field}(a))" for field in fields)
        probes.append(f"function {name}() -> (bits(5), bits(5)) = {{ let a : bits({width}) = undefined; ({old_result}, {new_result}) }}")
        for operation in ["Add", "Sub", "Sqrt", "MulAdd", "ToI32", "ToUi32", "ToI64", "ToUi64"]:
            name = f"pure_compare_f{width}{operation}"
            functions.append(name)
            result_width = 64 if operation.endswith("64") else 32 if operation.endswith("32") else width
            count = 3 if operation == "MulAdd" else 2 if operation in {"Add", "Sub"} else 1
            data = ["a", "b", "c"][:count]
            declarations = "\n".join(f"  let {arg} : bits({width}) = undefined;" for arg in data)
            rm = "0b100"
            for mode in reversed(range(4)):
                rm = f"ite(eq_anything(raw_rm, 0b{mode:03b}), 0b{mode:03b}, {rm})"
            actual = ", ".join(["rm"] + data)
            probes.append(f"""function {name}() -> (bits(5), bits({result_width}), bits(5), bits({result_width})) = {{
  let raw_rm : bits(3) = undefined;
  let rm = {rm};
{declarations}
  let (old_flags, old_bits) = audit_old_riscv_f{width}{operation}({actual});
  let (new_flags, new_bits) = riscv_f{width}{operation}({actual});
  (old_flags, old_bits, new_flags, new_bits)
}}""")
    probes.append("$endif")
    (args.output / "probes.sail").write_text("\n\n".join(probes) + "\n")
    (args.output / "functions.txt").write_text("\n".join(functions) + "\n")
    files = ["prelude.sail", "ieee_fp_primops.sail", "softfloat_interface.sail", "new_ieee_fp_exceptions.sail", "old_ieee_fp_exceptions.sail", "softfloat_symbolic.sail"]
    for width in (16, 32, 64):
        files.extend([f"new_softfloat_symbolic_f{width}.sail", f"old_softfloat_symbolic_f{width}.sail"])
    files.append("probes.sail")
    (args.output / "probe.sail_project").write_text("probe {\n  files\n    " + ",\n    ".join(files) + "\n}\n")
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
