# 片盒点检 · MediaPack Audit

**面向数字媒体素材交付的可复用预检库。** 核心是一个只读图像元数据的 MoonBit 库：读取一份 JSON 清单，检查交付目录中的 PNG/JPEG/WebP/GIF/BMP/TIFF/SVG/AVIF/JP2/ICO/PSD 是否缺失、尺寸是否正确、文件是否超限，以及有没有未登记的图片，并生成适合交付复核的 HTML 和 JSON 报告。仓库同时提供一个命令行入口（CLI）作为库的薄消费端。

> MoonBit Lang Hackathon 2026 项目方向：用 MoonBit 构建一个可复用的数字媒体预检库。核心聚焦在“素材包验收”，不做图像编辑器、素材生成器或通用文件管理器。

## 为什么做它

数字媒体项目经常要把海报、封面、社媒图和 UI 资源交给老师、客户或开发同伴。文件名看起来齐全，并不代表规格正确；人工逐项核对也容易漏掉缺图、尺寸错误或多交文件。片盒点检把交付要求写成清单，让检查结果可以重复运行、留档和分享。

## 能做什么

- 按清单递归检查素材目录中的相对路径是否存在、是否为普通文件；额外图片也会报告其相对路径。
- 读取 PNG IHDR、JPEG SOF、WebP VP8/VP8L/VP8X 头、GIF 逻辑屏幕、BMP DIB 头、TIFF 尺寸标签、SVG 宽高/viewBox、AVIF 的 ispe 属性盒、JPEG 2000 的 ihdr 盒、ICO/CUR 首项与 PSD 头核对像素宽高；PNG 会校验 IHDR 字段、逐块 CRC 和基本容器结构，WebP 会检查 RIFF 长度、块边界和奇数字节填充；不解码图像。
- JPEG 尺寸按 EXIF Orientation 换算为方向校正后的显示宽高，支持小端和大端 TIFF 标记；无效或不完整的 EXIF 方向信息会忽略并保留 SOF 尺寸。
- 检查文件大小上限，并报告目录中的额外 PNG/JPEG/WebP/GIF/BMP/TIFF/SVG/AVIF/JP2/ICO/PSD。
- 每项可选填写 expected_sha256，核对交付文件是否与预期内容一致；不匹配会让素材项失败。
- 素材项可选填 `aspect`，按 `W:H` 核对宽高比（精确整数比例），用于封面、社媒图等有固定比例的交付要求。
- 可选设置 max_total_bytes，限制整个素材目录树的总容量；递归统计所有普通文件，包括非图片文件。
- 当尺寸或文件大小不符合清单时，报告会同时写出要求值和实际值，方便直接定位该改哪项素材。
- 素材项可选填 `label`，用“课程主视觉”“微信公众号封面”等用途标注交付内容；HTML 与 JSON 报告保留该标签，HTML 会转义标签文本。
- JSON、HTML 和 CLI 摘要会记录所用清单原始字节的 SHA-256，方便把归档报告对应回当时的规格文件；清单空格或换行变化也会改变指纹。清单与图片指纹都只是内容标识，不是来源认证或数字签名。
- 在 JSON 与 HTML 报告中为已检查的 PNG/JPEG/WebP/GIF/BMP/TIFF/SVG/AVIF/JP2/ICO/PSD 生成 SHA-256 内容指纹，方便留档和核对重新导出的文件；它不证明素材来源或签名。相同指纹会提示潜在重复导出，仅供人工确认，不会判为失败。超过 max_bytes 上限的文件会跳过哈希与 expected_sha256 比较；PNG CRC/结构检查和 WebP RIFF 块边界检查仍会执行。
- 检查清单中的重复文件名、不安全路径和无效规格，并提示同一素材包中 SHA-256 相同的潜在重复文件；提示不改变通过/失败状态。
- 严格检查 JSON 清单字段：只接受顶层 `assets`、可选 `max_total_bytes` 及素材项中的 `file`、可选 `label`、`width`、`height`、`max_bytes`、可选 `min_bytes`、可选 `expected_sha256`、可选 `aspect`、可选 `format`；拼错或暂不支持的字段会在检查前指出路径并拒绝运行，并对拼写相近的字段给出“你是不是想写 X？”提示，重复字段（包括 JSON 转义后等价的字段名）也会被拒绝，避免规格被静默忽略。
- `width`、`height`、`max_bytes`、设置后的 `min_bytes` 和设置后的 `max_total_bytes` 必须为正整数；expected_sha256 必须是 64 位十六进制字符串；format 必须是受支持的格式名；小数不会被截断成另一个看似有效的规格。
- 按文件头识别实际图片格式，与扩展名不一致时给出“扩展名与内容不符”的明确提示；素材项可选填 `format` 断言交付文件的内容格式（接受 png/jpeg/webp/gif/bmp/tiff/svg/avif/jp2/ico/psd 及常见别名）。
- 素材项可选填 `min_bytes`，用于限制交付文件不得小于某个体积（例如拒绝被过度压缩或损坏为空的文件）。
- 输出带中文界面的独立 HTML 报告和机器可读 JSON 报告；报告对文件名和文本做 HTML 转义。
- 只读检查输入文件，不会改写或删除素材。

当前版本递归检查素材目录中的 PNG、JPEG、WebP、GIF、BMP、TIFF、SVG、AVIF、JP2、ICO 和 PSD；扩展名接受 `.png`、`.jpg`、`.jpeg`、`.webp`、`.gif`、`.bmp`、`.tif`、`.tiff`、`.svg`、`.avif`、`.jp2`、`.ico`、`.cur`、`.psd`，扩展名大小写不敏感，但清单路径必须使用 `/` 分隔，并与实际相对路径精确匹配（包括大小写）。绝对路径、反斜线和 `..` 路径段会被拒绝；扫描不跟随符号链接。尺寸来自 PNG IHDR、JPEG SOF（存在有效 EXIF Orientation 时换算成显示方向）、WebP 的 VP8/VP8L 头或 VP8X 画布字段、GIF 逻辑屏幕描述符、BMP 的 DIB 尺寸头、TIFF 的 ImageWidth/ImageLength 标签、SVG 的 width/height 属性或 viewBox（仅整数）、AVIF 的 ispe 属性盒、JPEG 2000 的 ihdr 盒、ICO/CUR 首项目录项以及 PSD 头。WebP 检查 RIFF 声明长度、块边界、必需的图像数据块和零填充，但不解析完整扩展元数据语义或动画帧数据。PNG 校验 IHDR CRC、标准规定的位深/颜色类型组合与方法值，并流式校验每个块的长度边界和 CRC，以及首块 IHDR、连续 IDAT、末块 IEND 等基本结构；它不执行完整的块类型语义验证，也不解压 IDAT 或解码像素。因此，这不等同于完整图像解码器或视觉验收；这些 PNG 规则依据 [W3C PNG 规范](https://www.w3.org/TR/png-3/)。WebP 字段依据 [Google WebP 容器规范](https://developers.google.com/speed/webp/docs/riff_container)、[VP8 数据格式规范（RFC 6386）](https://datatracker.ietf.org/doc/html/rfc6386) 与 [WebP Lossless Bitstream 规范](https://developers.google.com/speed/webp/docs/webp_lossless_bitstream_specification)。JPEG 元数据扫描最多读取文件开头 4 MiB；没有有效 EXIF Orientation 时，报告沿用 SOF 中存储的宽高。GIF 只检查画布宽高，不读取帧数或动画时序。对于未超过 `max_bytes` 的受支持图片，工具会以 64 KiB 缓冲区读取完整文件并记录 SHA-256；这可能需要比读取尺寸头更长的时间。超限文件显示 `—`，表示未计算哈希，但 PNG CRC 与结构检查仍会流式读取整个 PNG，WebP RIFF 检查仍会逐块读取块头和奇数长度填充字节。SHA-256 依赖固定版本 `moonbitlang/x@0.5.5` 的 [crypto 包](https://github.com/moonbitlang/x/tree/main/crypto)；该模块属于实验性包，项目锁定版本并只用其哈希功能。指纹仅用于内容比对，不是来源认证或数字签名。工具不检查色彩配置、透明边缘或视觉内容。GIF 字段依据 [GIF89a 规范](https://www.w3.org/Graphics/GIF/spec-gif89a.txt)。

## 生态调研与复用取舍

本项目按实际职责比较相邻实现，并复用可直接替代的通用算法：

| 项目/组件 | 已有能力 | 与片盒点检的关系与取舍 |
|---|---|---|
| [Pillow](https://pillow.readthedocs.io/en/stable/handbook/tutorial.html) | `Image.open()` 识别图像并提供尺寸、格式等属性；完整产品也支持像素解码和编辑 | 借鉴“先读格式与元数据”的使用流程；不移植 Python 实现，也不引入完整像素解码，因为本项目只做交付规格预检 |
| [mizchi/image](https://mooncakes.io/docs/mizchi/image) | PNG/BMP/JPEG 解码与编码，以及部分格式编码、缩放；解码结果为 RGBA 像素数据 | 面向编解码和图像处理。使用它获取尺寸会进入解码路径；本项目读取交付所需的容器元数据，并为格式差异做受限解析 |
| [gmlewis/moonbit-image](https://github.com/gmlewis/moonbit-image) | 基于 Go `image` 的简单 MoonBit 图像表示 | 面向图像数据表示；没有本项目需要的素材清单、目录验收与报告流程 |
| [hanbings/fluorescence](https://github.com/hanbings/fluorescence) | 仓库说明了 MoonBit BMP/PNG 读取及图像模糊、取色等能力 | 覆盖部分格式与图像处理，不包含本项目的素材包验收流程；不将其描述为没有图像读取能力 |
| [gmlewis/crc32](https://mooncakes.io/docs/gmlewis/crc32) / [moonbitlang/x/crypto](https://github.com/moonbitlang/x/tree/main/crypto) | CRC-32 与 SHA-256 通用算法 | 项目直接依赖前者验证 PNG CRC，依赖后者计算内容指纹，不重复实现哈希算法 |

MoonBit 生态中的图像库已经能承担像素解码、编码与处理；片盒点检把规格清单、目录对照、内容格式提示与可归档报告组合成独立可依赖的库。它可接在 posterkit 生成或 MoonBitMark 转换后的交付环节，承担最终规格核对。
## 快速开始

需要已安装 [MoonBit 工具链](https://www.moonbitlang.com/download/) 与可联网下载项目依赖的环境。本 CLI 使用主机文件系统，当前运行目标为 `native`（仓库已将其设为默认目标）。在仓库根目录运行：

```sh
moon check --target native
moon test
moon run --target native cmd/main -- examples/clean/media-pack.json examples/clean/assets --output report
```

命令会在 `report/` 下生成 `report.html` 和 `report.json`。打开 `report/report.html` 查看视觉报告。CLI 会先确认清单是文件、素材输入是目录；输入路径或清单有问题时给出错误并以非零状态退出。点检完成后，通过时退出码为 `0`；发现素材不合格时仍会先保存两种报告，再返回非零状态，适合接入 CI。

用 `init` 子命令从已有素材目录生成一份起步清单（自动读取每张图的宽高与大小，`max_bytes` 默认为实际大小的两倍、至少 1 KiB）：

```sh
moon run --target native cmd/main -- init examples/formats/assets --output media-pack.json
```

生成的清单写入 `media-pack.json`；若该路径已存在会拒绝覆盖，避免破坏手工修改过的清单。起步清单只包含自动读取的宽高和大小上限，`label`、`aspect`、`expected_sha256` 等字段需要人工按交付要求补充。

查看潜在重复内容的独立样例（两个 WebP 字节完全相同；报告提示 SHA-256 相同，但不影响通过状态）：

```sh
moon run --target native cmd/main -- examples/duplicates/media-pack.json examples/duplicates/assets --output report-duplicates
```

查看 SVG、AVIF、JPEG 2000、ICO 和 PSD 五种扩展格式全部通过规格的样例：

```sh
moon run --target native cmd/main -- examples/formats/media-pack.json examples/formats/assets --output report-formats
```

仓库还附带一个使用合成图片的刻意错误样例：`poster.png` 的清单宽高和大小上限不匹配，缺少 `social/card.png`，并多出未登记的 `texture.png`、`exports/cover.JPG`、`exports/preview.GIF`、`exports/thumbnail.webp` 和 `exports/thumbnail-copy.webp`。两个 WebP 文件内容相同，报告会展示规格问题、未登记项和潜在重复提示，并以退出码 1 结束，这是预期行为：

```sh
moon run --target native cmd/main -- examples/demo/media-pack.json examples/demo/assets --output report-issues
```

清单字段也有单独的错误样例：例如这个命令会指出 `width` 必须是整数并以非零状态退出，不会把 `4.5` 截断成 `4` 后生成通过报告：

```sh
moon run --target native cmd/main -- examples/invalid/fractional-width.json examples/clean/assets --output report-invalid-manifest
```

运行 CLI 端到端回归（核对原始清单 SHA-256、递归素材总大小预算通过与超限、小数和零预算拒绝、expected_sha256 大小写匹配与不匹配、无效摘要拒绝及超限跳过、JPEG EXIF 方向换算、未知顶层/素材字段和小数规格拒绝、PNG/WebP 哈希、清单图片间相同 SHA-256 的提示、额外图片与清单图片间的相同哈希提示、多种 WebP 头尺寸、无图像数据块的 VP8X 与非零 RIFF 填充拒绝、跨 64 KiB 的哈希分块、超限时跳过哈希、尺寸与文件大小错误同时显示要求值和实际值、非法 PNG IHDR、块长度越界、缺失 IEND、IEND 后尾随数据、IDAT CRC 错误、递归发现、路径越界拒绝、大小写不匹配、无效/缺失/类型错误输入、输出路径冲突）：

```sh
moon run --target native scripts/cli_smoke.mbtx
```

Windows PowerShell 同样可以使用以上 Moon 命令；查看报告可运行：

```powershell
Start-Process .\report\report.html
```

## 作为库使用

核心能力以 MoonBit 库的形式发布，CLI 只是它的薄消费端。在你的项目里添加依赖：

```sh
moon add hxiuzheng/media-pack-audit
```

仓库附有独立 MoonBit 包作为消费端示例：[`examples/library_consumer`](examples/library_consumer)。它导入本模块，读取 JSON 清单、调用 `scan_assets`，并从 `AuditReport` 生成 HTML/JSON。仓库根目录执行：

```sh
moon run --target native examples/library_consumer
```

在 `moon.pkg` 中引入并起别名：

```moonbit
import {
  "hxiuzheng/media-pack-audit" @audit,
}
```

公开 API 概览（均只读头部、不解码像素）：

- 尺寸解析：`png_dimensions` / `jpeg_dimensions` / `webp_dimensions` / `gif_dimensions` / `bmp_dimensions` / `tiff_dimensions` / `svg_dimensions` / `avif_dimensions` / `jp2_dimensions` / `ico_dimensions` / `psd_dimensions`，均接收 `Bytes` 返回 `(Int, Int)?`；
- 内容格式识别：`detect_content_format(bytes)` 按文件头返回 `ImageFormat?`，`format_name(format)` 取规范小写名；
- 清单读取与校验：`parse_manifest_json(text)` 拒绝重复键、未知字段和无效规格，返回 `Manifest` 或抛出 `ManifestParseError`；`scan_assets(asset_dir, manifest, manifest_sha256)` 返回 `AuditReport`；
- 报告生成：`render_html(report)` 生成中文 HTML，`AuditReport` 实现 `ToJson` 生成机器可读 JSON；
- 起步清单：`scaffold_manifest(asset_dir)` 从目录生成 `ScaffoldResult`；
- 通用工具：`sha256_bytes`、`parse_aspect` / `matches_aspect`、`closest_match`、`html_escape`。

最小示例（按文件头识别并读取单张图片的尺寸）：

```moonbit
fn inspect(bytes : Bytes) -> Unit {
  match @audit.detect_content_format(bytes) {
    Some(format) => {
      let dims : (Int, Int)? = match format {
        @audit.ImageFormat::Png => @audit.png_dimensions(bytes)
        @audit.ImageFormat::Jpeg => @audit.jpeg_dimensions(bytes)
        _ => None
      }
      println("格式 \{@audit.format_name(format)}，尺寸 \{dims}")
    }
    None => println("未识别的文件头")
  }
}
```

## 清单格式

```json
{
  "max_total_bytes": 100000,
  "assets": [
    { "file": "poster.png", "label": "课程主视觉", "width": 1920, "height": 1080, "max_bytes": 5000000 },
    { "file": "social/cover.jpeg", "width": 1200, "height": 630, "max_bytes": 2000000, "expected_sha256": "FF1EE418EE804BB1BEB25D59D3E5059FDFB9B2F6B7E97B81943D3ADEDAFD7458" },
    { "file": "social/cover.webp", "width": 1200, "height": 630, "max_bytes": 2000000 },
    { "file": "motion/preview.gif", "width": 320, "height": 180, "max_bytes": 500000 },
    { "file": "social-card.png", "width": 1200, "height": 630, "max_bytes": 2000000 }
  ]
}
```

每项都需要 `file`、`width`、`height` 和 `max_bytes`；可选 `label` 用于写明用途，并显示在 HTML/JSON 报告中。当前版本拒绝未识别字段（例如把 `max_bytes` 错拼成 `max_byts`），避免忽略用户写下的要求。宽、高、单项大小上限及总容量上限必须是正整数，小数会直接报错而不会被截断。`file` 可写为目录内相对路径，例如 `social/cover.jpeg`；使用 `/` 作为分隔符，不得使用绝对路径、反斜线或 `..` 路径段。

顶层可选填写正整数 `max_total_bytes` 限制整个素材目录树的容量。工具会递归累加其中所有普通文件（图片和非图片均计入），忽略符号链接，并在 JSON/HTML 报告中添加 `<package>` 汇总项；未设置时不执行总容量检查。

素材项可选填写 expected_sha256，值必须是 64 位十六进制 SHA-256（接受大小写混用）。工具用文件指纹与之比较；不匹配会使素材项失败并在报告中列出清单期望值。若文件超过 max_bytes，哈希计算和预期值比较都会跳过，报告会明确说明。在 Windows PowerShell 中可运行 `Get-FileHash .\poster.png -Algorithm SHA256`，将 Hash 列复制到清单；素材重新导出后应更新摘要。预期摘要用于核对内容，不是数字签名或来源认证。

素材项可选填写 `aspect`，值为 `W:H` 形式的正整数比例（例如 `16:9`、`4:3`、`1:1`）。工具用整数交叉相乘核对实际宽高是否精确符合该比例；例如要求 16:9 时，1920×1080 通过，而 1200×630（约 1.905:1）不通过。这是精确比例校验，不是近似判断；尺寸本身不满足精确比例时请勿填写该字段。

素材项可选填写 `min_bytes`，值为正整数，表示交付文件不得小于该体积。工具按文件头识别实际图片格式，与扩展名不一致时报告“扩展名与内容不符”；也可选填写 `format` 断言文件的内容格式，值接受 `png`、`jpeg`/`jpg`、`webp`、`gif`、`bmp`、`tiff`/`tif`、`svg`、`avif`、`jp2`、`ico`/`cur`、`psd`（大小写不敏感），与文件头识别出的实际格式不一致时判为失败。格式识别只读文件头，不解码像素。

## 项目结构

- `image.mbt`、`webp.mbt`、`svg.mbt`、`avif.mbt`、`jp2.mbt`、`ico.mbt`、`psd.mbt`：清单类型、各格式尺寸解析与素材点检逻辑。
- `isobmff.mbt`：AVIF 与 JPEG 2000 共用的 ISO-BMFF 盒结构解析器。
- `manifest.mbt`：`init` 子命令使用的起步清单生成器。
- `report.mbt`：HTML 报告及文本转义。
- `cmd/main`：命令行入口、`check`/`init` 子命令与报告落盘。
- `examples/demo`：可直接运行的多格式错误示例素材包（所有图片都是合成测试夹具）。
- `examples/clean`：所有规格都通过的素材包。
- `examples/formats`：SVG/AVIF/JP2/ICO/PSD 五种扩展格式全部通过的素材包。
- `examples/duplicates`：两份内容相同的 WebP 素材，演示潜在重复提示但仍通过。
- `examples/case-mismatch`：验证跨平台文件名大小写一致性的样例。
- `examples/invalid`：无效清单、路径越界、未知字段和小数规格样例。
- `scripts/cli_smoke.mbtx`：端到端验证 CLI 的退出码和报告生成。

## 当前验证基线与复现说明

本项目刻意把范围控制在可解释、可演示、可测试的一条链路：清单输入 → 文件点检 → HTML/JSON 交付报告。当前主分支的验证基线是 MoonBit `0.1.20260915 (2e1a46d)`；仓库依赖版本记录在 `moon.mod`，建议使用该版本或更新版本运行：

```sh
moon version --all
moon update
moon fmt --check
moon fmt --check scripts/cli_smoke.mbtx
moon check --target native --deny-warn
moon test --target native
moon run --target native scripts/cli_smoke.mbtx
```

如果本地工具链早于上述基线，依赖注册表可能无法解析当前版本的 `moonbitlang/async` 和 `moonbitlang/x`；这属于工具链兼容问题，不应被误报为测试通过。Ubuntu 与 Windows 的公开 CI 会执行同一组原生检查和 CLI 回归。

后续迭代优先做更好的错误提示、真实项目清单模板和测试覆盖，再考虑更多格式。选题上与 `moonbit-posterkit`、MoonBitMark 等生成/转换类项目的差异，见上文「与同类项目的区别」一节。

参赛项目简介、初审申报版和准备状态见 [`PROJECT_PROPOSAL.md`](PROJECT_PROPOSAL.md)、[`docs/片盒点检项目申报书_初审申报版.md`](docs/片盒点检项目申报书_初审申报版.md) 与 [`docs/initial-review-checklist.md`](docs/initial-review-checklist.md)。

## 人工主导、AI 辅助说明

本项目采用人工主导、AI 辅助的开发方式。项目方向、问题定义、格式支持范围、只读与安全边界、验收标准、公开声明和最终提交由参赛者本人决定。Codex 只用于 MoonBit API 查询、重复性代码草拟、边界用例枚举、编译诊断和文档整理。

AI 生成的建议不自动视为成果：每项改动都必须由参赛者检查源码、运行相关测试并理解其限制；未完成人工复核的改动不得作为最终参赛成果。仓库保留开发记录中的 AI 辅助披露，不改写历史来伪造纯人工作者。提交前的人工复核项目见 [`docs/human-review-checklist.md`](docs/human-review-checklist.md)。

## License

项目代码采用 Apache-2.0，详见 [LICENSE](LICENSE)。GIF 是 CompuServe Incorporated 的服务标记；尺寸字段按 [GIF89a 规范](https://www.w3.org/Graphics/GIF/spec-gif89a.txt)读取。
