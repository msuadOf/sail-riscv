#!/usr/bin/env python3
"""检查实际Sail汇编映射、FLI往返及GCC/Clang编码。"""

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "model"
SOURCES = {
    "zfa": MODEL / "extensions/FD/zfa_insts.sail",
    "scalar": MODEL / "extensions/bfloat16/zfbfmin_insts.sail",
    "rounding": MODEL / "extensions/FD/fext_insts.sail",
    "types": MODEL / "extensions/FD/freg_type.sail",
    "convert": MODEL / "extensions/bfloat16/zvfbfmin_insts.sail",
    "macc": MODEL / "extensions/bfloat16/zvfbfwma_insts.sail",
    "fregs": MODEL / "extensions/FD/fdext_regs.sail",
    "vregs": MODEL / "extensions/V/vext_regs.sail",
    "mask": MODEL / "extensions/V/vext_utils_insts.sail",
}

# Zfa 表的汇编立即数；H 的 65536.0 和 inf 必须保留为不同编码。
FLI_IMMEDIATES = [
    "-1.0", "min", "0.0000152587890625", "0.000030517578125",
    "0.00390625", "0.0078125", "0.0625", "0.125", "0.25", "0.3125",
    "0.375", "0.4375", "0.5", "0.625", "0.75", "0.875", "1.0",
    "1.25", "1.5", "1.75", "2.0", "2.5", "3.0", "4.0", "8.0",
    "16.0", "128.0", "256.0", "32768.0", "65536.0", "inf", "nan",
]


def assemble_texts(assembly_lines):
    """原文交给标准汇编器；调用者保留 returncode/stdout/stderr，不改写非法文本。"""
    return subprocess.run(
        ["llvm-mc", "-triple=riscv64",
         "-mattr=+f,+d,+v,+zfh,+zfa,+zfbfmin,+zvfbfmin,+zvfbfwma", "-show-encoding"],
        input="\n".join(assembly_lines) + "\n", text=True, capture_output=True,
    )


def decode_encodings(llvm_stdout):
    """读取 LLVM 输出中的小端机器码；有诊断时调用者不能按输入位置强行对应。"""
    return [int.from_bytes(bytes(int(byte, 16) for byte in encoding.split(",")), "little")
            for encoding in re.findall(r"encoding: \[([^]]+)\]", llvm_stdout)]


def definition(text, pattern):
    match = re.search(pattern + r"[^\n]*\n(?:[^\n]+\n)*", text, re.MULTILINE)
    if match is None:
        raise AssertionError(f"找不到源码定义: {pattern}")
    return match.group(0)


def cases():
    result = []
    for suffix, fmt in [("H", 2), ("S", 0), ("D", 1)]:
        for index, immediate in enumerate(FLI_IMMEDIATES):
            rd = index * 7 % 32
            result.append({
                "ctor": f"FLI_{suffix}(0b{index:05b}, Fregidx(0b{rd:05b}))",
                "assembly": f"fli.{suffix.lower()} f{rd}, {immediate}",
                "encoding": (0x78 | fmt) << 25 | 1 << 20 | index << 15 | rd << 7 | 0x53,
            })
    for vm in [0, 1]:
        mask = ", v0.t" if vm == 0 else ""
        for ctor, mnemonic, function in [
            ("VFNCVTBF16_F_F_W", "vfncvtbf16.f.f.w", 29),
            ("VFWCVTBF16_F_F_V", "vfwcvtbf16.f.f.v", 13),
        ]:
            result.append({
                "ctor": f"{ctor}(0b{vm}, Vregidx(0b00100), Vregidx(0b10000))",
                "assembly": f"{mnemonic} v16, v4{mask}",
                "encoding": 0x12 << 26 | vm << 25 | 4 << 20 | function << 15 | 1 << 12 | 16 << 7 | 0x57,
            })
        for suffix, kind, reg, function in [("VV", "Vregidx", "v", 1), ("VF", "Fregidx", "f", 5)]:
            result.append({
                "ctor": f"VFWMACCBF16_{suffix}(0b{vm}, Vregidx(0b00100), {kind}(0b01000), Vregidx(0b10000))",
                "assembly": f"vfwmaccbf16.{suffix.lower()} v16, {reg}8, v4{mask}",
                "encoding": 0x3b << 26 | vm << 25 | 4 << 20 | 8 << 15 | function << 12 | 16 << 7 | 0x57,
            })
    for rm, value in [("RNE", 0), ("RTZ", 1), ("RDN", 2), ("RUP", 3), ("RMM", 4), ("DYN", 7)]:
        for ctor, mnemonic, funct7, rs2 in [("FCVT_BF16_S", "fcvt.bf16.s", 0x22, 8), ("FCVT_S_BF16", "fcvt.s.bf16", 0x20, 6)]:
            text = f"{mnemonic} f16, f4, {rm.lower()}"
            if ctor == "FCVT_S_BF16":
                text = "fcvt.s.bf16 f16, f4" if value == 0 else f".insn r 0x53, {value}, 0x20, f16, f4, x6"
            result.append({"ctor": f"{ctor}(Fregidx(0b00100), RM_{rm}, Fregidx(0b10000))",
                           "assembly": text, "encoding": funct7 << 25 | rs2 << 20 | 4 << 15 | value << 12 | 16 << 7 | 0x53})
    return result


def probe_source(source_text, test_cases):
    parts = [
        "union fregidx = { Fregidx : bits(5) }\n",
        "union vregidx = { Vregidx : bits(5) }\n",
    ]
    parts.append(definition(source_text["types"], r"^enum rounding_mode ="))
    parts.append(definition(source_text["rounding"], r"^mapping frm_mnemonic :"))
    if "mapping bf16_widening_encoding_rm" in source_text["scalar"]:
        parts.append(definition(source_text["scalar"], r"^mapping bf16_widening_encoding_rm :"))
    for name in ["freg_abi_name_raw", "freg_arch_name_raw", "freg_name"]:
        parts.append(definition(source_text["fregs"], rf"^mapping {name} :"))
    for name in ["vreg_name_raw", "vreg_name"]:
        parts.append(definition(source_text["vregs"], rf"^mapping {name} :"))
    parts.append(definition(source_text["mask"], r"^mapping maybe_vmask :"))
    if "mapping fli_constant_mnemonic" in source_text["zfa"]:
        parts.append(definition(source_text["zfa"], r"^mapping fli_constant_mnemonic :"))
    parts += ["scattered union instruction\n", "val assembly : instruction <-> string\nscattered mapping assembly\n"]
    for key, ctors in [
        ("zfa", ["FLI_H", "FLI_S", "FLI_D"]),
        ("scalar", ["FCVT_BF16_S", "FCVT_S_BF16"]),
        ("convert", ["VFNCVTBF16_F_F_W", "VFWCVTBF16_F_F_V"]),
        ("macc", ["VFWMACCBF16_VV", "VFWMACCBF16_VF"]),
    ]:
        for ctor in ctors:
            parts.append(definition(source_text[key], rf"^union clause instruction = {ctor} :"))
            parts.extend(match.group(0) for match in re.finditer(rf"^mapping clause assembly = {ctor}\([^\n]*\n(?:[^\n]+\n)*", source_text[key], re.M))
    parts += ["end instruction\nend assembly\n", """
function check_case(ins : instruction, label : string) -> unit = {
  let text : string = assembly(ins);
  print_endline("CASE\\t" ^ label ^ "\\t" ^ text)
}
val main : unit -> unit
function main() = {
"""]
    parts.extend(f'  check_case({case["ctor"]}, "{index}");\n' for index, case in enumerate(test_cases))
    if "mapping fli_constant_mnemonic" in source_text["zfa"]:
        parts.extend(
            f'  assert(fli_constant_mnemonic(fli_constant_mnemonic(0b{index:05b})) == 0b{index:05b}, "FLI 立即数往返改变索引");\n'
            for index in range(32)
        )
    parts.append("  ()\n}\n")
    return "\n".join(parts)


def run(args, cwd, log, stdin=None):
    completed = subprocess.run(args, cwd=cwd, input=stdin, text=True, capture_output=True)
    log.write_text(completed.stdout + completed.stderr)
    if completed.returncode:
        raise RuntimeError(f"退出 {completed.returncode}: {args}; 见 {log}")
    return completed.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="仓库外独立输出目录")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    test_cases = cases()
    source_text = {key: path.read_text() for key, path in SOURCES.items()}
    # 逐定义抽取，不将生产 assembly 复制成另一份测试实现。
    probe = output / "assembly_probe.sail"
    probe.write_text(probe_source(source_text, test_cases))
    binary = output / "assembly_probe"
    run(["sail", "--strict-var", "--strict-bitvector", "--strict-exponentials",
         "--memo-z3-path", str(output / "sail_smt_cache"), "-c",
         "-o", str(binary), str(MODEL / "prelude/prelude.sail"), str(probe)],
        output, output / "build.log")
    sail_lib = Path(subprocess.check_output(["sail", "--dir"], text=True).strip()) / "lib"
    run(["cc", "-O1", "-I", str(sail_lib), str(binary.with_suffix(".c")),
         *(str(sail_lib / name) for name in ["sail.c", "sail_failure.c", "rts.c", "elf.c", "sail_config.c", "cJSON.c"]),
         "-lgmp", "-lz", "-o", str(binary)], output, output / "cc.log")
    text = run([str(binary)], output, output / "probe.log")
    printed = [line.split("\t", 2)[2] for line in text.splitlines() if line.startswith("CASE\t")]
    if len(printed) != len(test_cases):
        raise AssertionError(f"期望 {len(test_cases)} 条输出，实际 {len(printed)}")
    actual_asm = "\n".join(printed) + "\n"
    (output / "actual.s").write_text(actual_asm)
    llvm = assemble_texts(printed)
    (output / "llvm.log").write_text(llvm.stdout + llvm.stderr)
    failures = []
    expected_bytes = b"".join(case["encoding"].to_bytes(4, "little") for case in test_cases)
    (output / "actual.s").write_text(".text\n.option norelax\n" + actual_asm)
    toolchains = {}
    for name, command in [("gcc", ["riscv64-unknown-elf-gcc", "-march=rv64gcv_zfh_zfa", "-Wa,-march=rv64gcv_zfh_zfa_zfbfmin_zvfbfmin_zvfbfwma"]),
                          ("clang", ["clang", "--target=riscv64-unknown-elf", "-march=rv64gcv_zfh_zfa_zfbfmin_zvfbfmin_zvfbfwma"])]:
        obj = output / (name + ".o")
        cmd = command + ["-mabi=lp64d", "-c", str(output / "actual.s"), "-o", str(obj)]
        result = subprocess.run(cmd, capture_output=True, text=True)
        (output / (name + ".log")).write_text(result.stdout + result.stderr)
        actual = None
        if result.returncode == 0:
            raw = output / (name + ".bin")
            run(["riscv64-unknown-elf-objcopy", "-O", "binary", "-j", ".text", str(obj), str(raw)], output, output / (name + "-objcopy.log"))
            actual = raw.read_bytes()
        toolchains[name] = {"command": cmd, "exit": result.returncode, "bytes_match": actual == expected_bytes,
                            "version": subprocess.check_output([command[0], "--version"], text=True).splitlines()[0]}
        if actual != expected_bytes:
            failures.append({"toolchain": name, "exit": result.returncode, "bytes_match": False})
    for index, (actual, case) in enumerate(zip(printed, test_cases)):
        if actual != case["assembly"]:
            failures.append({"index": index, "actual": actual, "expected": case["assembly"]})
    encoded = decode_encodings(llvm.stdout)
    if llvm.returncode == 0 and len(encoded) == len(test_cases):
        for index, (actual, case) in enumerate(zip(encoded, test_cases)):
            if actual != case["encoding"]:
                failures.append({"index": index, "encoding": hex(actual), "expected": hex(case["encoding"])})
    else:
        failures.append({"llvm_returncode": llvm.returncode, "encoded_cases": len(encoded)})
    summary = {"toolchains": toolchains, "cases": len(test_cases), "sail_forward": len(printed),
               "sail_fli_roundtrip": 32 if "mapping fli_constant_mnemonic" in source_text["zfa"] else 0,
               "failures": failures,
               "source_sha256": {key: hashlib.sha256(text.encode()).hexdigest() for key, text in source_text.items()}}
    (output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    if failures:
        raise AssertionError(f"汇编回归失败 {len(failures)} 项；见 {output / 'summary.json'}")
    print(f"PASS: {len(test_cases)} 个 Sail assembly 输出、GCC/Clang及LLVM编码；32 个 FLI 立即数双向往返")


if __name__ == "__main__":
    main()
