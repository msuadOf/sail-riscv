#!/usr/bin/env python3
"""Run the reduction suite through real decode, execute, and state comparison."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("runner", "ir", "config", "cases", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results_path = args.output / "results.json"
    log_path = args.output / "run.log"
    command = [str(args.runner), str(args.ir), str(args.config),
               str(args.cases), str(results_path)]
    started = time.monotonic()
    with log_path.open("w") as log:
        try:
            returncode = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                        timeout=300, check=False).returncode
        except subprocess.TimeoutExpired:
            returncode = 124
    inputs = json.loads(args.cases.read_text())
    results = json.loads(results_path.read_text()) if results_path.exists() else []
    errors = []
    if len(inputs) != len(results):
        errors.append(f"case count {len(results)} != {len(inputs)}")
    for input_row, result in zip(inputs, results):
        name = input_row["name"]
        if result["name"] != name:
            errors.append(f"{name}: name mismatch")
        if result.get("expected") != input_row["expected"]:
            errors.append(f"{name}: expected fields changed")
        if result.get("decoded_ctor") != input_row["clause"]:
            errors.append(f"{name}: decoded_ctor = {result.get('decoded_ctor')}")
        if result.get("decoded_fields") != input_row["expected_fields"]:
            errors.append(f"{name}: decoded fields changed")
        reencoded = result.get("reencoded")
        if not isinstance(reencoded, str) or int(reencoded, 16) != int(input_row["word"], 16):
            errors.append(f"{name}: reencoded word changed")
        for register, expected in input_row["expected"].items():
            if result.get("registers", {}).get(register) != expected:
                errors.append(f"{name}: {register} = {result.get('registers', {}).get(register)}")
        for key in ("sat", "difference_unsat", "structural_ok"):
            if result.get(key) is not True:
                errors.append(f"{name}: {key} = {result.get(key)}")
        if result.get("execute_paths") != 1:
            errors.append(f"{name}: execute_paths = {result.get('execute_paths')}")
        expected_result = input_row.get("expected_result", "Retire_Success")
        if result.get("execute_result") != expected_result:
            errors.append(f"{name}: execute_result = {result.get('execute_result')}")
    manifest = {
        "command": command,
        "returncode": returncode,
        "seconds": round(time.monotonic() - started, 3),
        "inputs": len(inputs),
        "results": len(results),
        "errors": errors,
        "sha256": {name: sha256(path) for name, path in (
            ("runner", args.runner), ("ir", args.ir), ("config", args.config),
            ("cases", args.cases), ("results", results_path), ("log", log_path))
            if path.exists()},
    }
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({key: value for key, value in manifest.items() if key != "command"}))
    if returncode or errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
