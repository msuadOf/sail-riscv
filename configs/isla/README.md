# Isla workaround 配置

`workarounds/*.toml` 是 Isla 直接加载的执行限制配置，也是 Sail-RISC-V 模型侧唯一可编辑的 workaround 文件。`isla/scripts/run.mk` 中的目标从此目录读取；Isla 仓库不再保存第二份 TOML。

79 份配置均设 `strict = false`，`ir_sha256` 保留迁移时 d012 IR 的基准哈希。Isla 在 IR 哈希不同时输出 warning 并继续执行，不要求每次 IR 变化都改配置。只有修改了对应的 Sail 模型代码、导致受限分支或源码位置变化时，才核对并更新该配置的 `region_fork_limits`，必要时再更新基准哈希。`strict = false` 不保证旧区域仍命中原分支。

当前 `f8ce849` 已提交模型树对应的 132 个 region 与 22 处注释锚点已通过核对；迁移时暂存中的后续模型修改使部分坐标失效。当前验证状态和后续重绑入口见 isla-runner 的 `agents/workaround_ownership/status.md`。
