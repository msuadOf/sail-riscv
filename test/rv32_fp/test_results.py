#!/usr/bin/env python3
"""Fail closed on missing real-backward-decode evidence."""

import json
import pathlib
import sys


def main() -> None:
    cases = json.loads(pathlib.Path(__file__).with_name("cases.json").read_text())
    result = json.loads(pathlib.Path(sys.argv[1]).read_text())
    assert result["ir_xlen"] == 32
    assert result["config_vlen"] == 128
    assert result["config_elen"] == 64
    seen = {entry["name"]: entry for entry in result["cases"]}
    assert set(seen) == {case["name"] for case in cases}
    for case in cases:
        got = seen[case["name"]]
        assert got["input_bits"] == case["word"]
        assert got["decoded_ctor"] == case["ctor"]
        assert got["decoded_operands"] == case["operands"]
        assert got["backward_decode"] is True
        if case["name"] in {"fmvh_x_d", "fmvp_d_x"}:
            assert got["execute_ret_val"] == "Retire_Success"
            assert got["register_result_ok"] is True
            assert got["fflags_unchanged"] is True
            assert got["register_flags_unique"] is True
        else:
            assert got["memory_status"] == "pending_joint_memory"
    print("RV32 FP decode and two Zfa register effects PASS; Zcf memory pending")


if __name__ == "__main__":
    main()
