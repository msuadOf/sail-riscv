#!/usr/bin/env python3
"""编译并执行已准备的生产旧新函数探针，逐项限制时间并保留结论。"""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=Path)
parser.add_argument("plugin", type=Path)
parser.add_argument("--timeout", type=int, default=60)
parser.add_argument("--isla-lib", type=Path, default=Path(__file__).resolve().parents[3] / "isla/isla-lib")
args = parser.parse_args()
out = args.output.resolve()
functions = (out / "functions.txt").read_text().splitlines()
common = ["sail", "--strict-var", "--strict-bitvector", "--strict-exponentials", "--memo-z3-path", str(out / "cache"), "--all-modules"]
for symbolic in [False, True]:
    subprocess.run(common + (["-D", "SYMBOLIC"] if symbolic else []) + ["--just-check", str(out / "probe.sail_project")], check=True)
command = common + ["--plugin", str(args.plugin.resolve()), "--isla", "--isla-output-dir", str(out), "-o", "probe"]
for function in functions:
    command.extend(["--isla-preserve", function])
subprocess.run(command + [str(out / "probe.sail_project")], check=True)
subprocess.run(["python3", str(Path(__file__).with_name("check_ir.py")), str(out / "probe.ir")], check=True)
runner = out / "runner"
(runner / "src").mkdir(parents=True, exist_ok=True)
shutil.copyfile(Path(__file__).with_name("runner.rs"), runner / "src/main.rs")
(runner / "Cargo.toml").write_text('[package]\nname="isla-pure-compare-probe"\nversion="0.1.0"\nedition="2021"\n[dependencies]\nisla-lib={path=' + json.dumps(str(args.isla_lib.resolve())) + '}\n')
subprocess.run(["cargo", "build", "--quiet", "--manifest-path", str(runner / "Cargo.toml")], check=True)
binary = runner / "target/debug/isla-pure-compare-probe"
results = []
for function in functions:
    started = time.monotonic()
    try:
        proc = subprocess.run([str(binary), str(out / "probe.ir"), "z" + function], text=True, capture_output=True, timeout=args.timeout)
        result = {"function": function, "exit": proc.returncode, "seconds": time.monotonic() - started}
        (out / f"{function}.stdout").write_text(proc.stdout)
        (out / f"{function}.stderr").write_text(proc.stderr)
    except subprocess.TimeoutExpired:
        result = {"function": function, "timeout": args.timeout, "seconds": time.monotonic() - started}
    results.append(result)
    (out / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps(result), flush=True)
assert all(row.get("exit") == 0 for row in results), "存在失败或超时，不计通过"
