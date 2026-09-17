# 片盒点检 · MediaPack Audit

**面向数字媒体素材交付的轻量级预检 CLI。** 它读取一份 JSON 清单，检查交付目录中的 PNG/JPEG/WebP/GIF 是否缺失、尺寸是否正确、文件是否超限，以及有没有未登记的图片，并生成适合交付复核的 HTML 和 JSON 报告。

> MoonBit Lang Hackathon 2026 项目方向：用 MoonBit 构建一个可复现的数字媒体工作流小工具。核心聚焦在“素材包验收”，不做图像编辑器、素材生成器或通用文件管理器。

## 为什么做它

数字媒体项目经常要把海报、封面、社媒图和 UI 资源交给老师、客户或开发同伴。文件名看起来齐全，并不代表规格正确；人工逐项核对也容易漏掉缺图、尺寸错误或多交文件。片盒点检把交付要求写成清单，让检查结果可以重复运行、留档和分享。

## 能做什么

- 按清单递归检查素材目录中的相对路径是否存在、是否为普通文件；额外图片也会报告其相对路径。
- 读取 PNG IHDR、JPEG SOF、WebP VP8/VP8L/VP8X 头与 GIF 逻辑屏幕尺寸核对像素宽高；PNG 会校验 IHDR 字段、逐块 CRC 和基本容器结构，WebP 会检查 RIFF 长度、块边界和奇数字节填充；不解码图像。
- 检查文件大小上限，并报告目录中的额外 PNG/JPEG/WebP/GIF。
- 当尺寸或文件大小不符合清单时，报告会同时写出要求值和实际值，方便直接定位该改哪项素材。
- 在 JSON 与 HTML 报告中为已检查的 PNG/JPEG/WebP/GIF 生成 SHA-256 内容指纹，方便留档和核对重新导出的文件；它不证明素材来源或签名。相同指纹会提示潜在重复导出，仅供人工确认，不会判为失败。超过清单大小上限的文件会跳过哈希；PNG CRC/结构检查和 WebP RIFF 块边界检查仍会执行。
- 检查清单中的重复文件名、不安全路径和无效规格，并提示同一素材包中 SHA-256 相同的潜在重复文件；提示不改变通过/失败状态。
- 输出带中文界面的独立 HTML 报告和机器可读 JSON 报告；报告对文件名和文本做 HTML 转义。
- 只读检查输入文件，不会改写或删除素材。

当前版本递归检查素材目录中的 PNG、JPEG、WebP 和 GIF；扩展名接受 `.png`、`.jpg`、`.jpeg`、`.webp`、`.gif`，扩展名大小写不敏感，但清单路径必须使用 `/` 分隔，并与实际相对路径精确匹配（包括大小写）。绝对路径、反斜线和 `..` 路径段会被拒绝；扫描不跟随符号链接。尺寸来自 PNG IHDR、JPEG SOF、WebP 的 VP8/VP8L 头或 VP8X 画布字段、GIF 逻辑屏幕描述符。WebP 检查 RIFF 声明长度、块边界、必需的图像数据块和零填充，但不解析完整扩展元数据语义或动画帧数据。PNG 校验 IHDR CRC、标准规定的位深/颜色类型组合与方法值，并流式校验每个块的长度边界和 CRC，以及首块 IHDR、连续 IDAT、末块 IEND 等基本结构；它不执行完整的块类型语义验证，也不解压 IDAT 或解码像素。因此，这不等同于完整图像解码器或视觉验收；这些 PNG 规则依据 [W3C PNG 规范](https://www.w3.org/TR/png-3/)。WebP 字段依据 [Google WebP 容器规范](https://developers.google.com/speed/webp/docs/riff_container)、[VP8 数据格式规范（RFC 6386）](https://datatracker.ietf.org/doc/html/rfc6386) 与 [WebP Lossless Bitstream 规范](https://developers.google.com/speed/webp/docs/webp_lossless_bitstream_specification)。JPEG 元数据扫描最多读取文件开头 4 MiB。GIF 只检查画布宽高，不读取帧数或动画时序。对于未超过 `max_bytes` 的受支持图片，工具会以 64 KiB 缓冲区读取完整文件并记录 SHA-256；这可能需要比读取尺寸头更长的时间。超限文件显示 `—`，表示未计算哈希，但 PNG CRC 与结构检查仍会流式读取整个 PNG，WebP RIFF 检查仍会逐块读取块头和奇数长度填充字节。SHA-256 依赖固定版本 `moonbitlang/x@0.5.5` 的 [crypto 包](https://github.com/moonbitlang/x/tree/main/crypto)；该模块属于实验性包，项目锁定版本并只用其哈希功能。指纹仅用于内容比对，不是来源认证或数字签名。工具不检查色彩配置、透明边缘或视觉内容。GIF 字段依据 [GIF89a 规范](https://www.w3.org/Graphics/GIF/spec-gif89a.txt)。

## 快速开始

需要已安装 [MoonBit 工具链](https://www.moonbitlang.com/download/) 与可联网下载项目依赖的环境。本 CLI 使用主机文件系统，当前运行目标为 `native`（仓库已将其设为默认目标）。在仓库根目录运行：

```sh
moon check --target native
moon test
moon run --target native cmd/main -- examples/clean/media-pack.json examples/clean/assets --output report
```

命令会在 `report/` 下生成 `report.html` 和 `report.json`。打开 `report/report.html` 查看视觉报告。CLI 会先确认清单是文件、素材输入是目录；输入路径或清单有问题时给出错误并以非零状态退出。点检完成后，通过时退出码为 `0`；发现素材不合格时仍会先保存两种报告，再返回非零状态，适合接入 CI。

查看潜在重复内容的独立样例（两个 WebP 字节完全相同；报告提示 SHA-256 相同，但不影响通过状态）：

```sh
moon run --target native cmd/main -- examples/duplicates/media-pack.json examples/duplicates/assets --output report-duplicates
```

仓库还附带一个使用合成图片的刻意错误样例：`poster.png` 的清单宽高和大小上限不匹配，缺少 `social/card.png`，并多出未登记的 `texture.png`、`exports/cover.JPG`、`exports/preview.GIF`、`exports/thumbnail.webp` 和 `exports/thumbnail-copy.webp`。两个 WebP 文件内容相同，报告会展示规格问题、未登记项和潜在重复提示，并以退出码 1 结束，这是预期行为：

```sh
moon run --target native cmd/main -- examples/demo/media-pack.json examples/demo/assets --output report-issues
```

运行 CLI 端到端回归（核对 PNG/WebP 哈希、清单图片间相同 SHA-256 的提示、额外图片与清单图片间的相同哈希提示、多种 WebP 头尺寸、无图像数据块的 VP8X 与非零 RIFF 填充拒绝、跨 64 KiB 的哈希分块、超限时跳过哈希、尺寸与文件大小错误同时显示要求值和实际值、非法 PNG IHDR、块长度越界、缺失 IEND、IEND 后尾随数据、IDAT CRC 错误、递归发现、路径越界拒绝、大小写不匹配、无效/缺失/类型错误输入、输出路径冲突）：

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
    { "file": "social/cover.jpeg", "width": 1200, "height": 630, "max_bytes": 2000000 },
    { "file": "social/cover.webp", "width": 1200, "height": 630, "max_bytes": 2000000 },
    { "file": "motion/preview.gif", "width": 320, "height": 180, "max_bytes": 500000 },
    { "file": "social-card.png", "width": 1200, "height": 630, "max_bytes": 2000000 }
  ]
}
```

每项都需要 `file`、`width`、`height` 和 `max_bytes`。`file` 可写为目录内相对路径，例如 `social/cover.jpeg`；使用 `/` 作为分隔符，不得使用绝对路径、反斜线或 `..` 路径段。规格值必须是正数。

## 项目结构

- `image.mbt`、`webp.mbt`：清单类型、PNG/JPEG/WebP/GIF 尺寸解析与素材点检逻辑。
- `report.mbt`：HTML 报告及文本转义。
- `cmd/main`：命令行入口与报告落盘。
- `examples/demo`：可直接运行的多格式错误示例素材包（所有图片都是合成测试夹具）。
- `examples/clean`：所有规格都通过的素材包。
- `examples/duplicates`：两份内容相同的 WebP 素材，演示潜在重复提示但仍通过。
- `examples/case-mismatch`：验证跨平台文件名大小写一致性的样例。
- `scripts/cli_smoke.mbtx`：端到端验证 CLI 的退出码和报告生成。

## 参赛计划

本项目刻意把范围控制在可解释、可演示、可测试的一条链路：清单输入 → 文件点检 → HTML/JSON 交付报告。后续迭代优先做更好的错误提示、真实项目清单模板和测试覆盖，再考虑更多格式。是否与其他参赛者方向重叠，需要向活动组织者确认；提交项目前建议先发项目简介征求选题确认。

参赛项目简介和初审准备状态见 [`PROJECT_PROPOSAL.md`](PROJECT_PROPOSAL.md) 与 [`docs/initial-review-checklist.md`](docs/initial-review-checklist.md)。项目代码公开不代表已完成赛事报名或资格审核。

## AI 协作说明

开发过程中使用 Codex 辅助代码实现、MoonBit API 查询、测试和文档整理。参赛者需要逐项复核改动、理解实现并对最终提交负责；尚未理解的代码应先验证和学习，再作为参赛成果进行说明。

## License

项目代码采用 Apache-2.0，详见 [LICENSE](LICENSE)。GIF 是 CompuServe Incorporated 的服务标记；尺寸字段按 [GIF89a 规范](https://www.w3.org/Graphics/GIF/spec-gif89a.txt)读取。
