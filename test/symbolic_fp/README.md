# SYMBOLIC 浮点 B 阶段探针

本目录用小模型检查一个完整的 RISC-V helper：`riscv_f32Eq`。独立的
`demo_f32_add_bits` 只检查加法数值与规范 NaN 选值，不计算架构异常标志，
不得用作正式 `riscv_f32Add` 函数体。BF16 探针只检查
`RM,FP32 → BV16` 的接口以及精确输入 `1.0 → 0x3f80`；它不代表 BF16
异常或指令已经完成。

从工作区根目录运行。下面的插件构建和全部测试产物均放在临时目录，
不会覆盖正式 IR：

```sh
TEST_OUTPUT="$(mktemp -d)"
mkdir -p "$TEST_OUTPUT/plugin"
cp isla/isla-sail/dune isla/isla-sail/dune-project \
  isla/isla-sail/sail_plugin_isla.ml isla/isla-sail/jib_ir.ml \
  "$TEST_OUTPUT/plugin/"
(cd "$TEST_OUTPUT/plugin" && dune build --release)
ISLA_PLUGIN="$TEST_OUTPUT/plugin/_build/default/sail_plugin_isla.cmxs"
bash sail-riscv/test/symbolic_fp/check_stage_b.sh "$TEST_OUTPUT" "$ISLA_PLUGIN"
bash sail-riscv/test/symbolic_fp/run_stage_b.sh \
  "$TEST_OUTPUT/runtime" "$TEST_OUTPUT/stage_b.ir"
```

`check_stage_b.sh` 要求 Sail 至少为 0.20.1；本轮实际验证的版本是
0.20.1，提交 `446fb477c508853595ccc937ed60765aa685ae31`，后续版本
未验证。脚本检查 Sail 严格类型、Isla IR 的普通函数体和原生原语调用，
并通过 C++ 代码生成确认原 `softfloat_f32eq` extern 仍被选中。

B 阶段及拆分格式文件后的回归要求生成 IR 没有正式 `riscv_f32Add` 函数体，
避免用不完整 flags 通过数值演示。该时点的小模型 IR SHA-256 为
`ff577390946eef15c18b597f039d0271f871c72345cab8694e5629f3a0cb66e4`。
如需在 B 阶段源码快照重放这一门槛，设置 `STAGE_B_PHASE=pre_c`。
后续 C 阶段完成正式 Add 后，默认 `integrated` 只验证独立 demo 与
完整 Eq；不把新 Add 函数体误判为 B 回归失败。

`run_stage_b.sh` 在临时目录创建 Cargo manifest、lockfile 和 target，
使用本工作区的 `isla-lib` 和 Qfaufbv 执行生成的 IR。它对具体输入检查
Eq 的结果及五位 flags、加法位串和 BF16 接口；对未知输入先证明各测试
输入可满足，再证明结果或 flags 与预期不同不可满足。Eq 样例包括
qNaN、sNaN 和正负零；加法包括有限值与 qNaN。测试还要求未知输入的
纯 Eq、加法各只有一条完成路径，并用 `trace_functions` 证明确实进入
普通 Sail `riscv_f32Eq` 函数体。

完整模型生成时，在 `model/` 目录使用 `sail -plugin "$ISLA_PLUGIN" -isla`
与 `--all-modules riscv.sail_project`，显式传入
`--config "$BUILD_DIR/config/rv64d_v128_e64.json"`。输出目录应独立于正式
`rv64d.ir`。CMake 的 `generated_isla_rv64d` 目标默认选 VLEN256，不能作为
本计划 VLEN128 的验证产物。
