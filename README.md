# 片盒点检 · MediaPack Audit

**面向数字媒体素材交付的轻量级预检 CLI。** 它读取一份 JSON 清单，检查交付目录中的 PNG 是否缺失、尺寸是否正确、文件是否超限，以及有没有未登记的 PNG，并生成适合交付复核的 HTML 和 JSON 报告。

> MoonBit Lang Hackathon 2026 项目方向：用 MoonBit 构建一个可复现的数字媒体工作流小工具。核心聚焦在“素材包验收”，不做图像编辑器、素材生成器或通用文件管理器。

## 为什么做它

数字媒体项目经常要把海报、封面、社媒图和 UI 资源交给老师、客户或开发同伴。文件名看起来齐全，并不代表规格正确；人工逐项核对也容易漏掉缺图、尺寸错误或多交文件。片盒点检把交付要求写成清单，让检查结果可以重复运行、留档和分享。

## 能做什么

- 按清单逐项检查文件是否存在、是否为普通文件。
- 读取 PNG 文件头核对像素宽高；不把整张图片载入内存。
- 检查文件大小上限，并报告目录中的额外 PNG。
- 检查清单中的重复文件名、不安全路径和无效规格。
- 输出带中文界面的独立 HTML 报告和机器可读 JSON 报告；报告对文件名和文本做 HTML 转义。
- 只读检查输入文件，不会改写或删除素材。

当前版本只支持**单层目录中的小写 `.png` 文件**。尺寸检查依据 PNG IHDR 文件头，不解码像素、不验证整文件 CRC，也不检查色彩配置、透明边缘、视觉内容或子目录。它用于交付预检，不替代完整图像解码器和人工视觉验收。

## 快速开始

需要已安装 [MoonBit 工具链](https://www.moonbitlang.com/download/) 与可联网下载项目依赖的环境。在仓库根目录运行：

```sh
moon check --target native
moon test
moon run cmd/main -- examples/clean/media-pack.json examples/clean/assets --output report
```

命令会在 `report/` 下生成 `report.html` 和 `report.json`。打开 `report/report.html` 查看视觉报告。通过时退出码为 `0`；清单、目录有问题或检测发现未通过项时返回非零，适合接入 CI。检查发现不合格素材时仍会先保存两种报告。

仓库还附带一个刻意有问题的样例：它缺少 `social-card.png`，并多出未登记的 `texture.png`。运行后会生成报告并以退出码 `1` 结束，这是预期行为：

```sh
moon run cmd/main -- examples/demo/media-pack.json examples/demo/assets --output report-issues
```

运行 CLI 端到端回归（通过、检测失败、无效/缺失清单、输出路径冲突）：

```sh
moon run --target native scripts/cli_smoke.mbtx
```

Windows PowerShell 同样可以使用以上 Moon 命令；查看报告可运行：

```powershell
Start-Process .\report\report.html
```

## 清单格式

```json
{
  "assets": [
    { "file": "poster.png", "width": 1920, "height": 1080, "max_bytes": 5000000 },
    { "file": "social-card.png", "width": 1200, "height": 630, "max_bytes": 2000000 }
  ]
}
```

每项都需要 `file`、`width`、`height` 和 `max_bytes`。`file` 必须是文件名，不能包含目录路径；规格值必须是正数。

## 项目结构

- `png.mbt`：清单类型、PNG 头解析与素材点检逻辑。
- `report.mbt`：HTML 报告及文本转义。
- `cmd/main`：命令行入口与报告落盘。
- `examples/demo`：可以直接运行的最小示例素材包。
- `examples/clean`：所有规格都通过的素材包。
- `scripts/cli_smoke.mbtx`：端到端验证 CLI 的退出码和报告生成。

## 参赛计划

本项目刻意把范围控制在可解释、可演示、可测试的一条链路：清单输入 → 文件点检 → HTML/JSON 交付报告。后续迭代优先做更好的错误提示、真实项目清单模板和测试覆盖，再考虑更多格式。是否与其他参赛者方向重叠，需要向活动组织者确认；提交项目前建议先发项目简介征求选题确认。

## AI 协作说明

开发过程中使用 Codex 辅助代码实现、MoonBit API 查询、测试和文档整理。参赛者需要逐项复核改动、理解实现并对最终提交负责；尚未理解的代码应先验证和学习，再作为参赛成果进行说明。

## License

Apache-2.0，详见 [LICENSE](LICENSE)。
