# V 浮点合法性纯 Bool 探针

`before/` 冻结修改前两份完整生产文件，与 348147 候选模型的对应文件逐字相同。`build_probe.py` 抽取四个旧函数和现行函数到一个小 Sail 模型，并断言两份生产文件在四函数之外与冻结副本完全一致。探针保留 `vtype[vill]` 寄存器读取和 `vregidx` 单构造子，不使用输入域过滤。

从仓库根目录运行。先将 `OLD_IR`、`OLD_MODEL` 设为同一 348147 冻结候选的实际 IR 文件和 `model/` 目录；输出目录必须尚不存在：

```sh
python3 sail-riscv/test/solve_fp_legality/run.py \
  --output isla/target/float-solve-evidence/fp-legality-20260927/new-run \
  --old-ir "$OLD_IR" \
  --old-model "$OLD_MODEL" \
  --sail isla/target/float-solve-evidence/unified-backend-build/toolchain-a198-v2-20260927/sail-src/sail \
  --plugin isla/target/float-solve-evidence/unified-backend-build/toolchain-a198-v2-20260927/isla-plugin-src/_build/default/sail_plugin_isla.cmxs
```

`run.py` 用隔离 Sail 0.20.1 对普通和 SYMBOLIC 模式各做严格类型检查，要求旧 348147 IR 的四函数调用闭包在结构断言中失败；再生成小 IR，要求新闭包没有 Jump、goto、`eq_bits` 或 `neq_bits`。随后生成 C++ 并做语法编译。Isla 对任意 64 位 `vtype`、32 个 `vd`、2 个 `vm`、8 个 `rm` 和四个完整 `SEW` 值的每条完成路径证明四函数旧新 Bool 结果及 `vtype` 前后值相等；每条路径先要求 SAT，再要求差异 UNSAT。结果和全部命令、工具/输入/输出哈希保存在 `report.json`。

已完成的证据位于 `isla/target/float-solve-evidence/fp-legality-20260927/final-v1/`，`report.json` SHA-256 为 `242d3f87c271228c65a8ab14b525316749ac476502bf7963d67f0dc8b4ebfd9c`。旧 IR 红灯为 19 条 Jump/goto 或主动位串比较；新小 IR 六函数闭包零违规；四个 SEW 各有 15 条 SAT 路径，所有结果和状态差异均 UNSAT。此包不生成完整新模型 IR，也不替代正式入口的 R1、guard、Illegal 边或严格配置复验。
