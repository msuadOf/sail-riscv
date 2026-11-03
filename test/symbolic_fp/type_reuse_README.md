# Sail 浮点类型复用隔离验证

这个测试只编译共享 IEEE 异常库和 RISC-V 标志转换，验证模型复用 Sail 已有的 `float_rounding_mode`、`float_bits`、`fp_exception_flags`。异常公式内部保留五个 Bool 的 `ieee_fp_exceptions` 事实记录；在结果出口由 `ieee_pack_shared_flags` 转为共享 `fp_exception_flags`，随后 RISC-V 包装按 ISA 位序返回。它不调用指令执行入口，也不把 BF16 当作 f16。

从 `sail-riscv/` 根目录运行，先设置仓库外输出目录和已构建的 Isla Sail 插件路径：

```sh
mkdir -p "$TYPE_REUSE_RUN_DIR"
bash test/symbolic_fp/type_reuse_run.sh "$TYPE_REUSE_RUN_DIR" "$ISLA_PLUGIN" \
  > "$TYPE_REUSE_RUN_DIR/type_reuse_run.log" 2>&1
```

脚本先用 strict 选项检查 Sail，再生成隔离 IR，并用 Isla 执行。Rust 探针穷举五个异常事实的 32 种组合，分别检查共享位序 NV0/DZ1/OF2/UF3/NX4 和 RISC-V 位序 NV4/DZ3/OF2/UF1/NX0。分类对 f16/f32/f64 各检查正负零、次正规数、正规数、无穷、sNaN、qNaN，共各 12 个特殊值；每种格式再以真正未知位串运行一次，要求恰好一条可满足的完成路径。期望值在 Rust 测试中独立计算，不调用待测 Sail 分类函数。

完整数值和异常结果仍由 `test/ieee_exceptions/` 与三个格式包装差分测试检查。此处的单路径结果只针对分类探针，不代替所有指令与 helper 的验证。

2026-09-26 本轮上述命令退出码 0：32 种位序组合、每格式 12 个特殊值和 1 个未知输入单路径均 PASS。现行 C1 隔离 IR 的 SHA-256 为 `66f5cda3f7d3823703627be9562e46a70186f723276861511e8b0cdfe6461d04`；共享异常库源码的 SHA-256 为 `d80c4aabcc40f6c0de5aad439aab24a012de51a98ec1a3669ff4a52a781c9bf6`。原始输出见运行产物目录中的 `type_reuse_run.log`。验证仅覆盖本文件说明的类型、分类和位序合同。

同一 C1 源码另经 `test/ieee_exceptions/build_ir.sh` 生成 72 个隔离探针；`check.py --random-per-op 0 --prove` 的 738 例和 `check_conversions.py --random-per-source 0 --prove` 的 2652 例均退出码 0，逐例要求结果位与五个 flags 的差异不可满足。异常隔离 IR 的 SHA-256 为 `b33b8f4f1f4ae6a95061aac56dcba94026b084ecc2530f44622aef1e0f07ed41`。原始输出分别见同轮运行产物中的 `exception_build.log`、`arithmetic.log` 和 `conversions.log`；完整命令参数见 [异常测试说明](../ieee_exceptions/README.md)。
