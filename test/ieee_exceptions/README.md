# IEEE 异常库独立测试

本目录用一个最小 Sail project 调用 `model/core/ieee_fp_exceptions.sail`，由 Isla 执行普通 IR 函数。Rust probe 的参数是原始位串，输出五位异常和结果位；Python 脚本用仓库随附的 Berkeley SoftFloat RISCV 专用配置计算期望值。测试不依赖 RISC-V 指令状态。

从仓库根目录运行，以下变量均指向**仓库外**的构建目录或对应工具产物：

```sh
IR_BUILD_DIR=$(mktemp -d)
RUST_BUILD_DIR=$(mktemp -d)
ORACLE_BUILD_DIR=$(mktemp -d)
cmake -S agents/float_support_review/oracle -B "$ORACLE_BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$ORACLE_BUILD_DIR" -j 12
bash sail-riscv/test/ieee_exceptions/build_ir.sh "$IR_BUILD_DIR" "$ISLA_SAIL_PLUGIN"
CARGO_TARGET_DIR="$RUST_BUILD_DIR" cargo build --manifest-path sail-riscv/test/ieee_exceptions/Cargo.toml --offline
PROBE="$RUST_BUILD_DIR/debug/isla-ieee-exception-probe"
IR="$IR_BUILD_DIR/ieee_exceptions.ir"
ORACLE="$ORACLE_BUILD_DIR/oracle"
python3 sail-riscv/test/ieee_exceptions/check.py --probe "$PROBE" --ir "$IR" --oracle "$ORACLE" --random-per-op 100 --prove
python3 sail-riscv/test/ieee_exceptions/check_conversions.py --probe "$PROBE" --ir "$IR" --oracle "$ORACLE" --random-per-source 20 --prove
"$PROBE" "$IR" --symbolic "$ORACLE"
python3 agents/float_support_review/oracle/boundary_probe.py --probe "$PROBE" --ir "$IR" --oracle "$ORACLE"
python3 agents/float_support_review/oracle/conversion_boundary_probe.py --probe "$PROBE" --ir "$IR" --oracle "$ORACLE"
```

`ISLA_SAIL_PLUGIN` 是已构建的 Isla Sail 插件 `.cmxs` 文件路径。`build_ir.sh` 对所有 `*_probe` 使用 `--isla-preserve`；否则 Sail 特化会删除未作为 `isla_footprint` 根函数引用的探针。

`--prove` 对每例先要求输入 SAT，再断言本次五个 flags 或有效结果位与 SoftFloat 不同并要求 UNSAT。数值结果为 NaN 时只证明 flags，因通用 `fp_to_ieee` 的 NaN 编码未指定；FP→整数无效时只证明 flags，因通用转换的无效结果未指定。`--symbolic` 把 f32 Add/Sub/Div/FMA 的舍入模式和操作数声明为未知位串，约束到测试中列出的离散边界组合，再证明全部组合与 oracle 一致且仅有一条执行路径。以上证据不覆盖 ISA 的 canonical NaN、无效整数饱和值、寄存器和 fflags 累计。
