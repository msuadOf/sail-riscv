#!/usr/bin/env python3
"""只在外部目录从受测生产文件还原旧对照，核对冻结哈希后供比较探针使用。"""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=Path)
args = parser.parse_args()
test = Path(__file__).resolve().parent
root = test.parents[1]
output = args.output.resolve()
assert not output.is_relative_to(root), "旧对照只能写入源码仓库之外"
manifest = json.loads((test / "before-manifest.json").read_text())
for name in manifest:
    target = output / name
    assert not target.exists(), f"不覆盖已有快照: {target}"
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / name, target)
subprocess.run(["patch", "--batch", "--fuzz=0", "-p1", "-i", str(test / "before.patch")], cwd=output, check=True)
for name, expected in manifest.items():
    actual = hashlib.sha256((output / name).read_bytes()).hexdigest()
    assert actual == expected, f"旧快照不匹配: {name}: {actual} != {expected}"
print("四份旧生产文件已在外部目录还原，全部SHA-256匹配")
