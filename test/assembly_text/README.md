# 浮点汇编文本回归

此回归从当前模型源码抽取实际 `assembly` 映射及寄存器/掩码映射，生成独立 Sail 小模型，经 C 后端运行其正向打印，再用 GCC、Clang 驱动分别汇编并比较编码，保留 LLVM MC 检查。它不执行浮点数值语义，也不替代完整模型 IR 集成。

在仓库根目录运行，输出目录须在仓库外：

```sh
: "${ASSEMBLY_TEST_OUT:?set a fresh external output directory}"
python3 test/assembly_text/check.py "$ASSEMBLY_TEST_OUT"
```

依赖 `sail`、C 编译器、GMP/zlib 开发库和支持 Zfa/BF16 的 GCC/GNU assembler、Clang 和 `llvm-mc`；本次验证使用 Sail 0.20.1、LLVM 22.1.8。产物包括实际抽取的小模型、C/可执行文件、构建日志、Sail 输出、`actual.s`、LLVM 结果及带源文件 SHA-256 的 `summary.json`。

覆盖范围：

- FLI.H/S/D 每类全部 32 个立即数索引，共 96 条；目标寄存器遍历全部 32 个编号。
- 两种 BF16 向量转换、VV/VF 两种 BF16 MACC，每种分别有掩码、无掩码，共 8 条。
- 32 项 `fli_constant_mnemonic` 在 Sail 中 `index → token → index` 精确往返，保留 H 索引 29 (`65536.0`) 和 30 (`inf`) 的不同编码。
- 116 条输出逐字比较预期文本；GCC和Clang分别汇编，逐字节比较编码，LLVM MC另做逐条检查。
- 两个标量BF16转换各覆盖6个舍入编码。FCVT.S.BF16在rm=0时输出标准无舍入参数助记符，其他rm使用两套工具链均支持的`.insn r`字段形式，保留模型路径及编码；不更改执行语义。

Sail 0.20.1 的完整 `assembly_backwards` 被标记为不可执行，`assembly_backwards_matches` 在 C 后端也生成为匹配失败；本回归没有用自写解析器替代它们。可执行的纯字面值 FLI mapping 逆向与完整汇编的 LLVM 解析分别检查，不能把结果写成“完整 Sail assembly 逆向执行通过”。

其他回归可导入 `check.py` 的 `assemble_texts(lines)` 复用同一 LLVM 命令，返回保留 `returncode/stdout/stderr` 的 `CompletedProcess`；`decode_encodings(stdout)` 返回机器码整数列表。只有汇编器退出 0 且机器码数量与输入一致时，才能逐位置对应。函数不修正原文：旧 FLI 表索引和错误逗号应直接失败；正常 Illegal 保留编码被汇编器拒绝时，调用者需另按退休类别与模型 guard 解释。
