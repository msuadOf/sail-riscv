# 两个 V mapping 的小 IR 验证

`build_fixture.py` 从修改前后的 `vext_arith_insts.sail` 抽取 `encdec_nreg` 和 `vext_vs1`，在同一 Sail 小模型中生成旧、新 mapping 及外层 32 位 decoder。`runner.rs` 用 Isla 执行生成的 IR：穷举 bits5，验证部分值函数、有效值和 roundtrip，再对未知 bits5、32 位与邻近 16 位输入证明 Bool 或完整 AST 差异不可满足。

2026-09-26 的冻结源码、完整编译命令、工具与二进制哈希、运行日志在 `isla/target/float-solve-evidence/mapping-matches/20260926-2330/`。该目录的 `manifest.json` 给出命令数组和工作目录；专题结论见根仓库 `agents/float_support_review/solve-fix-mapping-matches.md`。这些小模型检查不替代集成 IR 的真实 decoder 对照。
