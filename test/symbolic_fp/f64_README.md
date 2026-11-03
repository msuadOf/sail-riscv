# f64 符号包装定向验证

本探针验证 [f64 包装文件](../../model/extensions/FD/softfloat_symbolic_f64.sail)中的 22 个 helper。它保留原 C++/Lem 声明，在独立 Isla 测试 IR 中运行 Sail 普通函数体，并使用父工作区的 [SoftFloat oracle](../../../agents/float_support_review/oracle/README.md)生成预期结果。

从父工作区根目录运行。插件和 oracle 的构建方式分别沿用[符号浮点探针说明](README.md)和上述 oracle 说明；下面给出完整的仓库外构建与测试命令：

```sh
F64_TEST_OUTPUT="$(mktemp -d)"
F64_PLUGIN_DIR="$F64_TEST_OUTPUT/plugin"
mkdir -p "$F64_PLUGIN_DIR"
cp isla/isla-sail/dune isla/isla-sail/dune-project \
  isla/isla-sail/sail_plugin_isla.ml isla/isla-sail/jib_ir.ml \
  "$F64_PLUGIN_DIR/"
(cd "$F64_PLUGIN_DIR" && dune build --release)
F64_PLUGIN="$F64_PLUGIN_DIR/_build/default/sail_plugin_isla.cmxs"

F64_ORACLE_DIR="$F64_TEST_OUTPUT/oracle"
cmake -S agents/float_support_review/oracle -B "$F64_ORACLE_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$F64_ORACLE_DIR" -j 12
F64_ORACLE="$F64_ORACLE_DIR/oracle"

bash sail-riscv/test/symbolic_fp/check_f64.sh "$F64_TEST_OUTPUT" "$F64_PLUGIN"
python3 sail-riscv/test/symbolic_fp/generate_f64_cases.py "$F64_ORACLE" \
  > "$F64_TEST_OUTPUT/f64_cases.txt"
timeout 600 bash sail-riscv/test/symbolic_fp/run_f64.sh \
  "$F64_TEST_OUTPUT/runtime" "$F64_TEST_OUTPUT/f64_probe.ir" \
  "$F64_TEST_OUTPUT/f64_cases.txt"
```

`check_f64.sh` 执行 Sail 严格类型检查，核对独立 IR 中 22 个 helper 的普通函数体；它还生成 C++ 并检查 Eq、FMA 两个入口仍调用原 SoftFloat 绑定。此处没有执行 C++ 版本，也没有逐个检查 22 个 C++ 绑定。

当前用例生成器输出 807 例，覆盖五种普通舍入方式、f64→f32 的 ROD 编码 6、特殊值、正负阈值邻点和固定种子的随机样本。运行器逐例比较完整结果位和五个 flags。它还通过 22 个未知输入入口分别确认只有一条完成路径、trace 进入普通 Sail 函数；对每个受限输入先证明 SAT，再证明结果或 flags 与 oracle 预期不同为 UNSAT。每次 SMT 调用限时 10 秒，整轮命令限时 600 秒；超时或 unknown 不算通过。

这些结果只覆盖独立测试 IR 中的 helper。正式 IR、指令合法性、寄存器写回、向量 mask 和 CSR 标志累计需要各自验证；随机样本不构成穷尽证明。
