# 九月 MoonBit 黑客松初审与验收准备清单

按 [2026 MoonBit 九月黑客松官方页面](https://moonbitlang.github.io/Hackathon2026/)核对，核对日期：2026-09-17。页面列出的申报与项目验收截止日为 **2026-09-24**，资格审核滚动进行。申报需提交参赛信息、公开仓库和一页项目说明；开发与验收看公开持续记录、MoonBit 主体实现、README、测试和可复现演示。最终以赛事正式章程与组织方通知为准。

## 仓库内可核验项

| 要求 | 当前证据 | 状态 |
|---|---|---|
| 公开可访问的项目仓库 | [GitHub 仓库](https://github.com/hxiuzheng/media-pack-audit) | 已满足 |
| 项目简介 / 一页选题说明 | [`PROJECT_PROPOSAL.md`](../PROJECT_PROPOSAL.md) | 草案已备；提交前须由参赛者补充真实场景并审阅 |
| MoonBit 为主要实现语言 | 核心逻辑、报告和 CLI 均为 `.mbt`；`.mbtx` 仅用于 MoonBit smoke 回归 | 已满足 |
| 清晰 README 与可运行示例 | [`README.md`](../README.md)、`examples/clean`、`examples/demo` | 已满足；本机按命令演示 |
| 必要测试 | 3 项单元测试及 CLI 端到端 smoke；覆盖通过、失败报告、大小写不一致、无效/缺失清单与输出路径冲突 | 已满足当前功能范围；继续按新增行为补测 |
| 跨平台 CI | [GitHub Actions 运行 #4](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35187263500)：Ubuntu、Windows 两个 job 均成功 | 已满足 |
| 连续、可追踪的开发过程 | Git 提交历史及 [`docs/development-log.md`](development-log.md) | 已有记录；截止前继续真实迭代 |
| 开源许可证 | 根目录 `LICENSE`：Apache-2.0 | 已满足 |
| AI 辅助透明且成果可解释 | README 与开发记录明确披露 Codex 辅助 | 文档已披露；参赛者本人仍须理解并能讲解代码 |

## 需要参赛者本人完成或确认

- 在官方页面提交参赛信息、公开仓库链接和项目简介；仓库准备工作不等于已经完成报名。
- 按官方要求加入赛事交流群，并留意资格审核与后续通知。
- 把“数字媒体素材交付规格预检”方向发给组织方，确认选题和工作范围适合本期赛事。对三个已检查项目的领域区分见 [`PROJECT_PROPOSAL.md`](../PROJECT_PROPOSAL.md)，不能据此保证与所有参赛者都不重叠。
- 用自己熟悉的真实素材交付场景试跑；记录素材来源、发现的问题和使用者反馈。当前仓库只有合成 fixture，不能声称已完成真实用户试用。
- 亲自从干净环境跟 README 重跑示例与测试，并准备现场讲解清单字段、PNG 文件头限制、大小写一致性处理和报告边界。

## 建议演示

在仓库根目录运行：

```sh
moon run cmd/main -- examples/clean/media-pack.json examples/clean/assets --output report
moon run cmd/main -- examples/demo/media-pack.json examples/demo/assets --output report-issues
moon run --target native scripts/cli_smoke.mbtx
```

第一条生成全通过报告；第二条演示缺失项与多余 PNG，并以非零状态结束（这是预期结果）；第三条自动检查 CLI 状态码与 JSON/HTML 报告。结束后可打开 `report/report.html` 和 `report-issues/report.html` 展示结果。
