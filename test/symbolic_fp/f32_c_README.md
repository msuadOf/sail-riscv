# f32 SYMBOLIC 包装测试

本测试通过隔离生成的 Isla IR，执行 23 个正式 f32 及整数转 f32 Sail helper 的普通函数体。测试逐位核对结果和五个异常标志，并检查纯 helper 的执行路径。指令译码、寄存器写回、CSR 标志累计、正式 V128 IR 和完整指令执行尚未测试。

Isla Sail 插件的构建方式见 [B 阶段说明](README.md)，独立 SoftFloat 参考工具的配置见 [oracle 说明](../../../agents/float_support_review/oracle/README.md)。下面的命令从 `sail-riscv/` 根目录运行；所有构建和运行产物均放在仓库外的临时目录：

```sh
OUT=$(mktemp -d)
mkdir -p "$OUT/plugin"
cp ../isla/isla-sail/dune ../isla/isla-sail/dune-project \
  ../isla/isla-sail/sail_plugin_isla.ml ../isla/isla-sail/jib_ir.ml \
  "$OUT/plugin/"
(cd "$OUT/plugin" && dune build --release)
ISLA_PLUGIN="$OUT/plugin/_build/default/sail_plugin_isla.cmxs"

cmake -S ../agents/float_support_review/oracle -B "$OUT/oracle" \
  -DCMAKE_BUILD_TYPE=Release
cmake --build "$OUT/oracle" -j 12
ORACLE_BIN="$OUT/oracle/oracle"

bash test/symbolic_fp/f32_c_check.sh "$OUT/ir" "$ISLA_PLUGIN"
CARGO_TARGET_DIR="$OUT/target" cargo build --quiet \
  --manifest-path test/ieee_exceptions/Cargo.toml
python3 test/symbolic_fp/f32_c_diff.py \
  --oracle "$ORACLE_BIN" \
  --probe "$OUT/target/debug/isla-ieee-exception-probe" \
  --ir "$OUT/ir/f32_c.ir" --random-per-op 50
python3 test/symbolic_fp/f32_conversion_cases.py \
  --oracle "$ORACLE_BIN" --output "$OUT/conversions.txt" \
  --random-per-helper 30
CARGO_TARGET_DIR="$OUT/target" bash test/symbolic_fp/f32_conversion_run.sh \
  "$OUT/runtime" "$OUT/ir/f32_c.ir" "$OUT/conversions.txt"
python3 test/symbolic_fp/f32_c_boundary_cases.py \
  --oracle "$ORACLE_BIN" --output "$OUT/boundaries.txt"
"$OUT/target/debug/sail-f32-conversion-probe" \
  "$OUT/ir/f32_c.ir" < "$OUT/boundaries.txt"
"$OUT/target/debug/sail-f32-conversion-probe" \
  "$OUT/ir/f32_c.ir" --unknown
```

差分探针对每个具体输入要求一条完成路径：先确认输入可满足，再证明“结果位或五个标志中任一个与 SoftFloat 不同”不可满足。当前覆盖算术与比较 570 例，其中固定 270 例、固定种子随机 300 例；转换与取整 3734 例，其中固定 1754 例、固定种子随机 1980 例。转换样例包含 ROD 内部编码 6，并直接检查四个普通候选结果在该编码下使用向零舍入；正式 ROD 结果另与 SoftFloat 的 round-to-odd 对照。

`f32_c_boundary_cases.py` 另生成 1178 个确定性边界样例：BF16 格式阈值 210 例，有符号与无符号 32/64 位整数转换边界 880 例，以及 f16 下溢、上溢附近的 ROD 结果和向零候选 88 例。这些样例覆盖正负号、sNaN/qNaN、无穷和适用的舍入方式；预期结果由固定 SoftFloat 参考工具生成，不使用待测 Sail 公式。

最后一条命令使 23 个 helper 分别以未知输入运行，并要求每项恰有一条可满足的完成路径。单路径检查不等于证明所有符号输入的数值和标志正确；上述差分结论只适用于列出的样例和隔离测试 IR。
