# SYMBOLIC 纯数据比较回归

本测试比较实际修改前后的 IEEE 分类、异常和整数饱和包装函数，避免位串/Bool 比较在构造浮点表达式时主动求解。只改模型纯数据比较；不修改架构 guard、舍入模式或全局 primop。

`before.patch` 与 `before-manifest.json` 固定本次修改前的四个生产文件。还原脚本仅在仓库外写旧对照，逐文件核对哈希。`prepare.py` 读取真实旧/新函数体，把旧函数重命名后放进同一小模型；两边复用同一套未修改依赖。生成的 manifest 记录每个实际输入文件的哈希。

```sh
PURE_COMPARE_OUTPUT=$(mktemp -d)
python3 sail-riscv/test/solve_pure_compare/restore_before.py "$PURE_COMPARE_OUTPUT/before"
python3 sail-riscv/test/solve_pure_compare/prepare.py \
  "$PURE_COMPARE_OUTPUT/before" "$PURE_COMPARE_OUTPUT/compare"
python3 sail-riscv/test/solve_pure_compare/run.py \
  "$PURE_COMPARE_OUTPUT/compare" "$ISLA_PLUGIN"
```

`ISLA_PLUGIN` 指向当前已构建的 Isla Sail 插件。默认 runner 依赖主工作区 `isla/isla-lib`，也可通过 `--isla-lib` 指定已冻结的候选。工具先跑非 SYMBOLIC/SYMBOLIC 两种严格类型检查，再生成 IR、检查比较调用和执行 27 项旧新证明。每项上限默认 60 秒，失败或超时令工具失败并保留逐项结果。

覆盖范围：

- 三种完整未知位串分别检查 NaN、sNaN、inf、zero、finite 的五位分类结果等价。
- f16/f32/f64 的 Add、Sub、Sqrt、MulAdd 和四种 32/64 位有符号/无符号整数转换，共 24 项。原始浮点位串完全未知，舍入模式由纯 ITE 映射覆盖普通 0–4 五种取值。
- 每项要求唯一完成路径、SAT，然后对完整输出的任何差异要求 UNSAT。四元组同时比较完整五 flags 和结果位；NaN 规范化与整数无效返回也在比较内。
- IR 检查要求新分类闭包不调用 `eq_bits/neq_bits`，24 个数据 sign/饱和函数体不出现 `eq_bits/neq_bits/eq_bool/neq_bool` 或分支。`float_decompose` 按具体位宽选择格式的分支允许保留。

修改前的真实分类 IR 在 `is_all_ones → eq_bits` 处触发结构红灯；修改后通过。基线比对不等于独立 oracle：它证明本次比较替换保留原有语义，SoftFloat 差分和完整指令回归仍须由最终候选完成。普通 RM 比较继续使用既有实现，不在本包结构检查范围内。
