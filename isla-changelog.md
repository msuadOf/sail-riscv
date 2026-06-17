# Isla 兼容性修改日志

本文件记录为适配 isla 符号执行引擎而对 sail-riscv 模型所做的修改。

---

## 2026-06-04: STORE/STORECON/STORE_FP 中 width 相关 slice 的 subrange_internal 符号化错误

### 原因

`word_width` 是枚举类型 `{1, 2, 4, 8}`。isla 符号执行时，`width` 参数被当作符号化变量（覆盖所有枚举值）。

原始代码中 `X(rs2)[width * 8 - 1 .. 0]` 的 slice 上界 `width * 8 - 1` 因此也是符号化的。
isla-lib 的 `subrange_internal` 实现要求 slice 高/低索引为具体整数，遇到符号化索引时返回 `SymbolicLength` 错误，
导致 STORE、STORECON、STORE_FP 等指令在符号执行中崩溃或走 Illegal_Instruction 路径。

### 受影响的指令

- STORE (`zSTORE`)
- STORECON (`zSTORECON`)
- STORE_FP (`zSTORE_FP`)

### 修复方案

由于 Sail 的依赖类型系统要求 match 各分支返回同一类型，而 `bits(8)`, `bits(16)`, `bits(32)`, `bits(64)` 是不同类型，
不能单独对 `data` 做 match。因此将 `data` 的 slice 和 `vmem_write` 调用整体放入 `match width` 中，
每个分支独立构造 data 并调用 vmem_write，slice 索引均为具体常量：

```sail
(* 原始代码 *)
let data = X(rs2)[width * 8 - 1 .. 0];
match vmem_write(rs1, offset, width, data, Store(Data), false, false, false) {
  Ok(_) => RETIRE_SUCCESS,
  Err(e) => e,
}

(* 修改后 *)
match width {
  1 => match vmem_write(rs1, offset, 1, X(rs2)[7 .. 0], Store(Data), false, false, false) {
    Ok(_) => RETIRE_SUCCESS,
    Err(e) => e,
  },
  2 => match vmem_write(rs1, offset, 2, X(rs2)[15 .. 0], Store(Data), false, false, false) {
    Ok(_) => RETIRE_SUCCESS,
    Err(e) => e,
  },
  4 => match vmem_write(rs1, offset, 4, X(rs2)[31 .. 0], Store(Data), false, false, false) {
    Ok(_) => RETIRE_SUCCESS,
    Err(e) => e,
  },
  8 => match vmem_write(rs1, offset, 8, X(rs2)[63 .. 0], Store(Data), false, false, false) {
    Ok(_) => RETIRE_SUCCESS,
    Err(e) => e,
  },
}
```

isla 符号执行引擎会在 `match width` 处 fork 为 4 条路径，每条路径中 `width` 被约束为具体枚举值，
后续的 `subrange_internal` 调用接收到的都是具体索引，不再报错。

STORECON 和 STORE_FP 同理修改。

### 修改的文件

| 文件 | 行号（原始） | 说明 |
|------|-------------|------|
| `model/extensions/I/base_insts.sail` | 322 | STORE execute |
| `model/extensions/A/zalrsc_insts.sail` | 70 | STORECON execute |
| `model/extensions/FD/fext_insts.sail` | 321 | STORE_FP execute |

### 注意事项

- 此修改不影响 C/Lean 仿真器的行为，语义完全等价
- `vmem_read`/`vmem_write` 内部仍有 `zeros(...)` 等依赖符号化 `width` 的操作，可能触发更深层 `SymbolicLength` 错误（LOAD 系列 TIMEOUT 的原因之一），后续需进一步处理