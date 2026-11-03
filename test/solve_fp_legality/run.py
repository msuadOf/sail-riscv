#!/usr/bin/env python3
"""Rebuild the frozen old/new V legality probe and record each verification step."""

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

TEST = Path(__file__).resolve().parent
REPO = TEST.parents[2]


def digest(path):
    return sha256(Path(path).read_bytes()).hexdigest()


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", required=True, type=Path)
parser.add_argument("--old-ir", required=True, type=Path)
parser.add_argument("--old-model", required=True, type=Path)
parser.add_argument("--sail", required=True, type=Path)
parser.add_argument("--plugin", required=True, type=Path)
args = parser.parse_args()
out = args.output.resolve()
old_ir = args.old_ir.resolve()
old_model = args.old_model.resolve()
sail = args.sail.resolve()
plugin = args.plugin.resolve()
for name in ("vext_utils_insts.sail", "vext_fp_utils_insts.sail"):
    assert digest(TEST / "before" / name) == digest(old_model / "extensions/V" / name), name

subprocess.run([sys.executable, str(TEST / "build_probe.py"), str(out)], check=True)
steps = []


def step(name, argv, expected=0, cwd=out, env=None):
    result = subprocess.run(argv, cwd=cwd, text=True, capture_output=True, env=env)
    stdout = out / f"{name}.stdout.log"
    stderr = out / f"{name}.stderr.log"
    stdout.write_text(result.stdout)
    stderr.write_text(result.stderr)
    steps.append({"name": name, "argv": [str(x) for x in argv], "cwd": str(cwd),
                  "exit_code": result.returncode, "expected_exit_code": expected,
                  "stdout_sha256": digest(stdout), "stderr_sha256": digest(stderr)})
    assert result.returncode == expected, (name, result.returncode, result.stderr[-1000:])


strict = [str(sail), "--strict-var", "--strict-bitvector", "--strict-exponentials",
          "--require-version", "0.20.1", "--all-modules"]
step("cpp-strict", strict + ["--memo-z3-path", "memo-cpp", "--just-check", "probe.sail_project"])
step("symbolic-strict", strict + ["-D", "SYMBOLIC", "--memo-z3-path", "memo-symbolic",
                           "--just-check", "probe.sail_project"])
step("old-ir-red", [sys.executable, str(TEST / "check_ir.py"), str(old_ir),
                    "--report", str(out / "old-ir-structure.json")], expected=1)
old_structure = json.loads((out / "old-ir-structure.json").read_text())
assert old_structure["status"] == "FAIL"
assert {row["kind"] for row in old_structure["violations"]} == {
    "control_flow", "active_bit_equality"}
step("small-ir", [str(sail), "-plugin", str(plugin), "-isla", "-D", "SYMBOLIC",
                  "--strict-var", "--strict-bitvector", "--strict-exponentials",
                  "--require-version", "0.20.1", "--all-modules", "--memo-z3-path",
                  "memo-symbolic", *sum((["--isla-preserve", f"proof_sew{sew}"]
                                          for sew in (8, 16, 32, 64)), []),
                  "--isla-output-dir", str(out), "-o", "legality", "probe.sail_project"])
step("new-ir-green", [sys.executable, str(TEST / "check_ir.py"),
                      str(out / "legality.ir"), "--report", str(out / "new-ir-structure.json")])
step("cpp-emit", strict + ["--cpp", "--c-no-main", "--memo-z3-path", "memo-cpp",
                           *sum((["--c-preserve", name] for name in
                                 ("valid_vtype", "valid_rd_mask", "valid_fp_op",
                                  "illegal_fp_normal")), []),
                           "-o", "legality_cpp", "probe.sail_project"])
step("cpp-syntax", ["g++", "-std=c++17", "-fsyntax-only", "-I",
                    str(sail.parent / "lib"), "legality_cpp.cpp"])
runner = out / "runner"
(runner / "src").mkdir(parents=True)
shutil.copyfile(TEST / "runner.rs", runner / "src/main.rs")
(runner / "Cargo.toml").write_text('[package]\nname="fp-legality-proof"\nversion="0.1.0"\n'
                                     'edition="2021"\n[dependencies]\nisla-lib={path=' +
                                     json.dumps(str(REPO / "isla/isla-lib")) + '}\n[workspace]\n')
step("runner-build", ["cargo", "build", "--offline", "--release", "--manifest-path",
                      str(runner / "Cargo.toml")], env={**os.environ,
                      "CARGO_TARGET_DIR": str(out / "runner-target")})
binary = out / "runner-target/release/fp-legality-proof"
step("symbolic-proof", [str(binary), str(out / "legality.ir")])
assert (out / "symbolic-proof.stdout.log").read_text().count("difference UNSAT") == 4

report = {
    "status": "PASS",
    "scope": "four V legality helpers; arbitrary vtype64/vd5/vm1/rm3; SEW 8,16,32,64",
    "old_ir_sha256": digest(old_ir),
    "old_model_source": {name: digest(TEST / "before" / name) for name in
                         ("vext_utils_insts.sail", "vext_fp_utils_insts.sail")},
    "sail_sha256": digest(sail.parent / "_build/install/default/bin/sail"),
    "plugin_sha256": digest(plugin),
    "tools_sha256": {name: digest(TEST / name) for name in
                     ("build_probe.py", "check_ir.py", "runner.rs", "run.py")},
    "outputs_sha256": {name: digest(out / name) for name in
                       ("manifest.json", "probe.sail", "legality.ir", "legality_cpp.cpp",
                        "old-ir-structure.json", "new-ir-structure.json",
                        "symbolic-proof.stdout.log")},
    "steps": steps,
}
(out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"status": report["status"], "report": str(out / "report.json"),
                  "sha256": digest(out / "report.json")}))
