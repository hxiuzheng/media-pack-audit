# 九月 MoonBit 黑客松初审与验收准备清单

按 [2026 MoonBit 九月黑客松官方页面](https://moonbitlang.github.io/Hackathon2026/)核对，核对日期：2026-09-26。申报需提交参赛信息、公开仓库和项目说明；开发与验收看公开持续记录、MoonBit 主体实现、README、测试和可复现演示。最终以赛事正式章程与组织方通知为准。

## 仓库内可核验项

| 要求 | 当前证据 | 状态 |
|---|---|---|
| 公开可访问的项目仓库 | [GitHub 仓库](https://github.com/hxiuzheng/media-pack-audit) | 已满足 |
| 项目简介 / 一页选题说明 | [`PROJECT_PROPOSAL.md`](../PROJECT_PROPOSAL.md) | 已备 |
| MoonBit 为主要实现语言 | 核心逻辑、报告和 CLI 均为 `.mbt`；`.mbtx` 仅用于 MoonBit smoke 回归 | 已满足 |
| 清晰 README 与可运行示例 | [`README.md`](../README.md)、`examples/clean`、`examples/duplicates`、`examples/demo` | 已满足；本机按命令演示 |
| 必要测试 | PNG/JPEG/WebP/GIF/BMP/TIFF 尺寸测试；JPEG EXIF Orientation 大小端换算与无效值回退；WebP VP8、VP8L、VP8X 和 RIFF 边界；PNG CRC 与结构边界；总容量预算、宽高比、expected_sha256、未知字段、小数规格、重复 JSON 字段、用途标签、HTML 转义、分块读取、重复内容、递归扫描、路径越界和 CLI smoke | 已有仓库测试与公开 CI 记录 |
| 跨平台 CI | `.github/workflows/ci.yml` 在 Ubuntu 与 Windows 上执行格式、无警告检查、原生测试和 CLI smoke；具体运行号以当前主分支提交对应的 Actions 记录为准 | 已配置；提交前复核最新运行 |
| 连续、可追踪的开发过程 | Git 提交历史及 [`docs/development-log.md`](development-log.md) | 已有记录 |
| 开源许可证 | 根目录 `LICENSE`：Apache-2.0 | 已满足 |
| AI 辅助透明且成果可解释 | README 与开发记录明确披露 Codex 辅助 | 已披露 |

## 需要参赛者本人完成或确认

- 在官方页面提交参赛信息、公开仓库链接和项目简介；仓库准备工作不等于已经完成报名。
- 按官方要求加入赛事交流群，并留意资格审核与后续通知。
- 选题区分已在 [`PROJECT_PROPOSAL.md`](../PROJECT_PROPOSAL.md) 说明：片盒点检做素材包“验收”，与 `moonbit-posterkit`、MoonBitMark 等“生成/转换”类项目互补而非重叠。
- 用自己熟悉的真实素材交付场景试跑；记录规格来源、命中情况、误报/漏报、耗时和使用者反馈，填写 [真实素材试用记录模板](real-use-trial-template.md)。
- 亲自从干净环境跟 README 重跑示例与测试，并完成 [`docs/human-review-checklist.md`](human-review-checklist.md)，准备现场讲解清单字段、PNG chunk CRC 与不解压 IDAT 的边界、JPEG SOF 与 EXIF Orientation 显示方向、WebP VP8/VP8L/VP8X 尺寸头与 RIFF 边界、GIF 逻辑屏幕尺寸限制、BMP/TIFF 头解析、相对路径安全策略、扩展名与路径大小写处理和报告边界。

## 建议演示

在仓库根目录运行：

```sh
moon run --target native cmd/main -- examples/clean/media-pack.json examples/clean/assets --output report
moon run --target native cmd/main -- examples/duplicates/media-pack.json examples/duplicates/assets --output report-duplicates
moon run --target native cmd/main -- examples/demo/media-pack.json examples/demo/assets --output report-issues
moon run --target native scripts/cli_smoke.mbtx
```

第一条生成全通过的多格式报告；第二条展示两份内容相同的 WebP 且仍保持通过状态；第三条使用合成夹具演示尺寸、大小上限不符、缺失项、多余图片和潜在重复提示，并以非零状态结束（这是预期结果）；第四条自动检查 CLI 状态码与 JSON/HTML 报告。结束后可打开 `report/report.html`、`report-duplicates/report.html` 和 `report-issues/report.html` 展示结果。
