# 开发记录

记录实际完成的改动和验证结果，不追记或拆分此前没有发生的工作。

## 2026-09-17：CLI 退出码、目录复用与端到端验证

- CLI 现在在素材全部通过时返回 `0`；发现素材问题、缺失输入或无效清单时返回非零。检测报告会在发现素材问题时照常保存。
- 输出路径若已是目录可重复使用；若该路径被普通文件占用，会给出明确错误并返回非零。
- 增加全通过素材样例、无效清单 fixture、`.mbtx` 端到端回归脚本，以及 push / pull request 触发的 MoonBit CI。
- smoke 回归覆盖全通过、素材有问题、无效清单、缺失清单、输出路径冲突，并检查 HTML/JSON 报告内容。脚本连续运行两次均通过，验证了报告目录可以复用。
- 本轮使用 Codex 辅助实现和验证；最终提交内容仍需参赛者本人理解并负责。

验证命令：

```text
moon update
moon fmt --check
moon fmt --check scripts/cli_smoke.mbtx
moon check --target native --deny-warn
moon test --target native        # 3 passed
moon run --target native scripts/cli_smoke.mbtx
```

- 首次推送后的 [GitHub Actions 运行](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35186539702) 全部通过；Actions 提示 `checkout@v4` 使用的 Node 20 运行时正在弃用，因此将 workflow 更新为官方 `actions/checkout@v7`。更新后的 workflow 随后再次运行验证。
- 更新后的 [GitHub Actions 运行](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35186658315) 也全部通过，包括格式、无警告检查、测试和 CLI 端到端回归。

## 2026-09-17：跨平台精确匹配文件名

- 修正 Windows 等大小写不敏感文件系统上的清单匹配：现在先核对目录枚举到的原始文件名，再打开文件，避免大小写不一致时把同一个素材同时报告为通过和多余。
- 新增 `Poster.png` 与清单 `poster.png` 的跨平台 fixture，并将结果固定为“清单文件缺失 + 未登记文件”两项，不允许误报通过。
- 更新 README，明确清单名称（含大小写）需与实际目录项完全一致。
- CI 现在同时在 Ubuntu 和 Windows runner 执行 MoonBit 格式、检查、测试及端到端 smoke 回归，覆盖此次修复针对的大小写差异环境。
- 本轮由 Codex 辅助实现；改动和 fixture 已在本机复核，参赛者仍需理解并负责最终实现。

本地 Windows 验证通过：`moon fmt --check`、`moon fmt --check scripts/cli_smoke.mbtx`、`moon check --target native --deny-warn`、`moon test --target native`（3 passed）。`moon run --target native scripts/cli_smoke.mbtx` 连续运行两次均通过，覆盖通过、发现项、大小写不匹配、无效/缺失清单和输出路径冲突。本轮 Ubuntu / Windows 远端 CI 结果将在推送后补记。
