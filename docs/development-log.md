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

本地 Windows 验证通过：`moon fmt --check`、`moon fmt --check scripts/cli_smoke.mbtx`、`moon check --target native --deny-warn`、`moon test --target native`（3 passed）。`moon run --target native scripts/cli_smoke.mbtx` 连续运行两次均通过，覆盖通过、发现项、大小写不匹配、无效/缺失清单和输出路径冲突。提交 `0e4edaf` 的 [Ubuntu / Windows 远端 CI](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35187263500) 两个 job 均通过。

## 2026-09-17：初审材料与选题核对

- 按 [九月黑客松官方页面](https://moonbitlang.github.io/Hackathon2026/)整理公开仓库、项目简介、MoonBit 主体、README、测试、可复现示例、开发记录、开源许可和 AI 可解释等要求。
- 收紧 `PROJECT_PROPOSAL.md` 为基于当前真实实现的一页选题简介，并对照参赛者此前提到的三个项目说明问题域差别；没有把局部对比表述为全赛事查重保证。
- 新增初审清单，分别列出仓库中已有证据与需要参赛者本人完成的报名、入群、组织方选题确认和真实用户试用；明确这些事项目前没有可验证的完成记录。
- README 加入申报材料入口，避免把“仓库已公开”误写成“已报名或通过审核”。

本轮为材料整理，没有新增代码功能。Windows 本机重跑 `moon fmt --check`、`moon fmt --check scripts/cli_smoke.mbtx`、`moon check --target native --deny-warn`、`moon test --target native`（3 passed）和 CLI smoke 均通过；另外直接运行全通过与发现问题两个 README 演示，分别得到预期退出码 `0` 和 `1`，并生成 HTML / JSON 文件。后续优先取得一名数字媒体同学的真实试用反馈，再据此扩充高价值功能。

## 2026-09-17：增加 JPEG 素材规格预检

- 扩展名支持 `.png`、`.jpg`、`.jpeg`，扩展名比较不区分大小写；完整文件名仍按目录中的实际拼写精确匹配。
- 新增 JPEG marker / SOF 尺寸读取，支持常见 baseline、progressive 等 SOF 类型；JPEG 元数据最多扫描文件开头 4 MiB，不解码整张图。
- 将干净样例扩展为 PNG + 1200×630 JPEG，并在问题样例中加入大写扩展名 `.JPG`，覆盖真实格式识别和大小写行为。
- 新增 JPEG baseline、progressive、损坏 marker / frame length 单元测试；README、项目简介与初审清单同步说明支持范围和边界。
- 本轮由 Codex 辅助实现；JPEG 样例由 Pillow 生成且可正常解码。工具只读取尺寸元数据，不验证像素内容、完整解码或 ICC / 色彩配置；参赛者仍需理解并负责最终实现。

Windows 本机验证通过：`moon fmt --check`、`moon fmt --check scripts/cli_smoke.mbtx`、`moon check --target native --deny-warn`、`moon test --target native`（6 passed）与 `moon run --target native scripts/cli_smoke.mbtx`；Pillow 确认 `.jpeg` 与 `.JPG` 样例均为 1200×630 JPEG。远端 CI 待推送后验证。
