# 片盒点检 · MediaPack Audit

**清单驱动的通用文件包校验库，提供可选的图像元数据校验。** 调用者用 JSON 清单声明文件和约束，库检查清单项是否存在、路径是否安全、文件大小/摘要是否符合要求，并报告包内未登记文件。对 PNG/JPEG/WebP/GIF/BMP/TIFF/SVG/AVIF/JP2/ICO/PSD，还可按需校验格式、尺寸和宽高比。公开 API 可由 MoonBit 应用调用，命令行入口（CLI）是供人工操作或 CI 调用的薄消费端；输入清单和目录，输出结构化结果及 HTML/JSON 报告。

> 项目边界：它是清单驱动的资源包验收组件，不是图像编辑器或像素解码器。通用文件检查不依赖图像格式；图像尺寸等规则是可选的领域扩展。

## 十月新生态项目建设与已有原型

项目已有前期原型，包括媒体清单点检、图像元数据读取、路径与容量约束、HTML/JSON 报告、公开库接口及独立消费示例。当前按十月“新生态项目建设”方向准备申报；相关赛道沟通事实需参赛者本人核实。既有原型作为当前基础说明，不重复计入本期新增工作。

| 十月新增与完善 | 具体变化 | 代码与复现依据 |
|---|---|---|
| 通用文件包校验 | 图片必填尺寸改为可选；普通文件可按大小和摘要验收，未登记的非图像文件也会报告 | [`f7a78a1`](https://github.com/hxiuzheng/media-pack-audit/commit/f7a78a1)；`examples/library_consumer` 的文本附件消费示例 |
| 通用目录清单生成及转义修复 | `init` 纳入普通文件；生成含控制字符路径时使用合法 JSON 转义，保留图片尺寸的可选生成 | [`4daa2f7`](https://github.com/hxiuzheng/media-pack-audit/commit/4daa2f7) 至 [`25f16e4`](https://github.com/hxiuzheng/media-pack-audit/commit/25f16e4)；`manifest.mbt` 单测与 CLI 草稿回读、拒绝覆盖场景 |
| 直接库调用的约束校验 | 修复直接构造规格时非法约束可能被忽略的问题；与 JSON 入口共用规则并拒绝矛盾大小区间 | [`163a9d3`](https://github.com/hxiuzheng/media-pack-audit/commit/163a9d3)；独立消费包的 3 项测试及 CLI 无效清单回归 |
| AVIF 主图元数据关联解析 | 不再把 `ipco` 中第一个 `ispe` 当作主图尺寸；解析 `pitm` 主 item 与 `ipma` 属性索引，再按索引解析 `ipco`，区分主图和缩略图并拒绝缺失、越界或含糊关联 | `avif.mbt` 的多 item 回归：缩略图先出现时仍选主图；未关联的 `ispe` 被拒绝；扩展属性结构边界检查 |
| AVIF 有界结构一致性核心 | 串联 `pitm → iinf/infe → ipma/ipco → iloc → mdat/idat`，验证 item 引用、属性索引、主图尺寸/配置/位深关系及数据区间归属；公开纯函数和文件入口返回可定位诊断 | `avif_structure.mbt`、`avif_structure_file.mbt`；`avif_structure_wbtest.mbt` 的单约束破坏对照与边界回归；CLI smoke 的真实 AVIF 变异样例与跨包消费 |

十月还适配了 MoonBit `0.1.20261012` 的类型与接口写法；这属于工具链维护。直接构造 `AssetSpec` 的旧调用者须把必填的 `width`/`height` 改为 `Some(宽)`/`Some(高)`，或同时使用 `None`；旧 JSON 清单中成对的整数尺寸仍可使用。当前公开字段及函数签名见 `pkg.generated.mbti`。

新生态项目建设方向的提交截止为 **2026-10-31**；Mooncakes 发布安排在后续验收阶段，当前仓库不将元数据或可调用示例视为已经发布。提交版本仍需参赛者本人完成源码、限制及公开声明的复核；自动测试与 CI 记录不能替代该复核。

## 为什么做它

数字媒体项目经常要把海报、封面、社媒图和 UI 资源交给老师、客户或开发同伴。文件名看起来齐全，并不代表规格正确；人工逐项核对也容易漏掉缺图、尺寸错误或多交文件。片盒点检把交付要求写成清单，让检查结果可以重复运行、留档和分享。

## 三个可验证的预期使用场景

以下是设计用途与仓库内的复现依据，不是外部采用、用户反馈或生态合作记录。合成图片和本仓库消费端只能验证功能路径；真实试用应另按[试用记录模板](docs/real-use-trial-template.md)记录规格来源、运行结果与人工核对结论。

| 预期场景与调用者 | 输入与规则 | 调用路径和可核对结果 |
|---|---|---|
| MoonBit 应用验收发布附件或文档包 | `examples/library_consumer` 的 `release-notes.txt`；仅约束相对路径及 20–2048 bytes 的大小范围，无图像字段 | 独立包调用公开的清单解析、扫描和报告 API；应得到 `checked=1`、`passed=1`、`failed=0`，并生成清单 SHA-256 和 HTML/JSON 报告 |
| 交付者或 CI 检查媒体资源规格 | `examples/clean` 清单与素材目录；检查图片尺寸、文件上限、预期 SHA-256 和整包 100000 bytes 预算 | CLI 应返回 `0`，报告 `passed=7`、`failed=0`（6 个文件及 1 个 `<package>` 汇总项）；受控错误包 `examples/demo` 应返回 `1`，保留报告并指出规格不符、缺件和未登记项 |
| 维护者为已有目录建立清单草稿 | 现有普通文件目录；自动填入相对路径和大小上限，可读取尺寸的受支持图片另填宽高 | `init` 为非图像目录生成不含宽高的清单；生成清单可回读验收。相同输出路径再次执行应拒绝覆盖；图片目录的尺寸生成另由 `examples/formats` 及 CLI 回归验证 |

在仓库根目录依次复现（需要下文说明的 native 工具链环境；第三个场景的草稿路径须尚不存在）：

```sh
# 1. 独立包消费公开 API；报告位于 _build/library-consumer/
moon run --target native examples/library_consumer

# 2. 通过包与受控错误包；两次运行均应生成 report.html 和 report.json
moon run --target native cmd/main -- examples/clean/media-pack.json examples/clean/assets --output _build/scenarios/clean
moon run --target native cmd/main -- examples/demo/media-pack.json examples/demo/assets --output _build/scenarios/issues

# 3. 从非图像目录起草清单，再用草稿检查同一目录；预期均返回 0
moon run --target native cmd/main -- init examples/library_consumer/assets --output _build/scenarios/draft.json
moon run --target native cmd/main -- _build/scenarios/draft.json examples/library_consumer/assets --output _build/scenarios/draft-check
```

第二个场景的错误包返回 `1` 是预期的拒收结果，自动化脚本须显式检查该退出码。完整的 `scripts/cli_smoke.mbtx` 回归会断言通过/失败退出码、报告内容、普通文件与图片的清单生成、草稿回读和拒绝覆盖。草稿依据文件现状生成，只能作为起点，仍需由维护者按独立的交付要求修订；不能用“草稿检查自身通过”证明符合真实规格。

维护范围围绕上述复用路径展开：严格清单与路径规则、文件约束、可选图像检查和报告。当前证据限于仓库代码、样例与测试；本说明不据此声称已有外部项目接入、生态合作或真实用户验证。

## 能做什么

- 按清单递归检查素材目录中的相对路径是否存在、是否为普通文件；清单未登记的文件也会报告其相对路径。
- 对任意普通文件均可执行清单存在性、路径安全、容量上限/下限和可选 SHA-256 校验；非图像文件不要求提供图像尺寸字段。
- 读取 PNG IHDR、JPEG SOF、WebP VP8/VP8L/VP8X 头、GIF 逻辑屏幕、BMP DIB 头、TIFF 尺寸标签、SVG 宽高/viewBox、AVIF 主 item 关联的 ispe、JPEG 2000 的 ihdr 盒、ICO/CUR 首项与 PSD 头核对像素宽高；PNG 会校验 IHDR 字段、逐块 CRC 和基本容器结构，WebP 会检查 RIFF 长度、块边界和奇数字节填充；不解码图像。
- JPEG 尺寸按 EXIF Orientation 换算为方向校正后的显示宽高，支持小端和大端 TIFF 标记；无效或不完整的 EXIF 方向信息会忽略并保留 SOF 尺寸。
- 对受支持图像可校验文件大小，并报告格式、尺寸或宽高比；图像校验是通用文件包校验之上的可选能力。
- 每项可选填写 expected_sha256，核对交付文件是否与预期内容一致；不匹配会让素材项失败。
- 素材项可选填 `aspect`，按 `W:H` 核对宽高比（精确整数比例），用于封面、社媒图等有固定比例的交付要求。
- 可选设置 max_total_bytes，限制整个素材目录树的总容量；递归统计所有普通文件，包括非图片文件。
- 当尺寸或文件大小不符合清单时，报告会同时写出要求值和实际值，方便直接定位该改哪项素材。
- 素材项可选填 `label`，用“课程主视觉”“微信公众号封面”等用途标注交付内容；HTML 与 JSON 报告保留该标签，HTML 会转义标签文本。
- JSON、HTML 和 CLI 摘要会记录所用清单原始字节的 SHA-256，方便把归档报告对应回当时的规格文件；清单空格或换行变化也会改变指纹。清单与文件指纹都只是内容标识，不是来源认证或数字签名。
- 对清单内未超出 `max_bytes` 的文件生成 SHA-256 内容指纹，方便核对文件内容；它不证明来源或签名。相同指纹会提示潜在重复文件，仅供人工确认，不会判为失败。超限文件会跳过哈希与 expected_sha256 比较；PNG CRC/结构检查和 WebP RIFF 块边界检查仍会执行。
- 检查清单中的重复文件名、不安全路径和无效规格，并提示同一素材包中 SHA-256 相同的潜在重复文件；提示不改变通过/失败状态。
- 严格检查 JSON 清单字段：只接受顶层 `assets`、可选 `max_total_bytes` 及素材项中的 `file`、可选 `label`、`width`、`height`、`max_bytes`、可选 `min_bytes`、可选 `expected_sha256`、可选 `aspect`、可选 `format`；拼错或暂不支持的字段会在检查前指出路径并拒绝运行，并对拼写相近的字段给出“你是不是想写 X？”提示，重复字段（包括 JSON 转义后等价的字段名）也会被拒绝，避免规格被静默忽略。
- `max_bytes`、设置后的 `min_bytes` 和设置后的 `max_total_bytes` 必须为正整数；`width` 和 `height` 若填写必须成对且为正整数；expected_sha256 必须是 64 位十六进制字符串；format 必须是受支持的图像格式名；小数不会被截断成另一个看似有效的规格。
- 按文件头识别实际图片格式，与扩展名不一致时给出“扩展名与内容不符”的明确提示；素材项可选填 `format` 断言交付文件的内容格式（接受 png/jpeg/webp/gif/bmp/tiff/svg/avif/jp2/ico/psd 及常见别名）。
- 素材项可选填 `min_bytes`，用于限制交付文件不得小于某个体积（例如拒绝被过度压缩或损坏为空的文件）。
- 输出带中文界面的独立 HTML 报告和机器可读 JSON 报告；报告对文件名和文本做 HTML 转义。
- 只读检查输入文件，不会改写或删除素材。

清单可列出任意普通文件，通用检查覆盖路径、存在性、大小、摘要和未登记文件；图像元数据仅支持以下格式。扩展名接受 `.png`、`.jpg`、`.jpeg`、`.webp`、`.gif`、`.bmp`、`.tif`、`.tiff`、`.svg`、`.avif`、`.jp2`、`.ico`、`.cur`、`.psd`，扩展名大小写不敏感，但清单路径必须使用 `/` 分隔，并与实际相对路径精确匹配（包括大小写）。绝对路径、反斜线和 `..` 路径段会被拒绝；扫描不跟随符号链接。尺寸来自 PNG IHDR、JPEG SOF（存在有效 EXIF Orientation 时换算成显示方向）、WebP 的 VP8/VP8L 头或 VP8X 画布字段、GIF 逻辑屏幕描述符、BMP 的 DIB 尺寸头、TIFF 的 ImageWidth/ImageLength 标签、SVG 的 width/height 属性或 viewBox（仅整数）、AVIF 主 item 关联的 ispe 属性、JPEG 2000 的 ihdr 盒、ICO/CUR 首项目录项以及 PSD 头。AVIF 扫描使用下节定义的有界结构一致性验证：关联主图声明、属性和 `iloc` 数据区间；元数据读取限于文件开头 4 MiB，不检查 AV1 码流或解码像素。WebP 检查 RIFF 声明长度、块边界、必需的图像数据块和零填充，但不解析完整扩展元数据语义或动画帧数据。PNG 校验 IHDR CRC、标准规定的位深/颜色类型组合与方法值，并流式校验每个块的长度边界和 CRC，以及首块 IHDR、连续 IDAT、末块 IEND 等基本结构；它不执行完整的块类型语义验证，也不解压 IDAT 或解码像素。因此，这不等同于完整图像解码器或视觉验收；这些 PNG 规则依据 [W3C PNG 规范](https://www.w3.org/TR/png-3/)。WebP 字段依据 [Google WebP 容器规范](https://developers.google.com/speed/webp/docs/riff_container)、[VP8 数据格式规范（RFC 6386）](https://datatracker.ietf.org/doc/html/rfc6386) 与 [WebP Lossless Bitstream 规范](https://developers.google.com/speed/webp/docs/webp_lossless_bitstream_specification)。JPEG 元数据扫描最多读取文件开头 4 MiB；没有有效 EXIF Orientation 时，报告沿用 SOF 中存储的宽高。GIF 只检查画布宽高，不读取帧数或动画时序。对于未超过 `max_bytes` 的受支持图片，工具会以 64 KiB 缓冲区读取完整文件并记录 SHA-256；这可能需要比读取尺寸头更长的时间。超限文件显示 `—`，表示未计算哈希，但 PNG CRC 与结构检查仍会流式读取整个 PNG，WebP RIFF 检查仍会逐块读取块头和奇数长度填充字节。SHA-256 依赖固定版本 `moonbitlang/x@0.5.5` 的 [crypto 包](https://github.com/moonbitlang/x/tree/main/crypto)；该模块属于实验性包，项目锁定版本并只用其哈希功能。指纹仅用于内容比对，不是来源认证或数字签名。工具不检查色彩配置、透明边缘或视觉内容。GIF 字段依据 [GIF89a 规范](https://www.w3.org/Graphics/GIF/spec-gif89a.txt)。

## AVIF 有界结构一致性验证

这项十月增量在 MoonBit 中自行实现 item、属性与数据来源之间的约束检查。CRC-32、SHA-256 仍复用已有依赖，不计入这项核心；不依赖 Pillow 或 libavif 执行检查。格式依据为 [AOM AVIF §2 图像属性、§6 品牌与 §9 文件结构](https://aomediacodec.github.io/av1-avif/)，并参考 [libavif 的 ISOBMFF 读取实现](https://github.com/AOMediaCodec/libavif/blob/main/src/read.c)核对字段版本和宽度。以下是实现的子集，不代表完整 AVIF/HEIF 合规性认证。

| 关系或边界 | 本实现检查 |
|---|---|
| 主图与声明 | `pitm` 指向唯一、非零的 `iinf/infe` 声明，主图类型须为直接 `av01`；计数与实际条目一致，拒绝重复 ID |
| 属性引用 | 所有 `ipma` 的 item 必须已声明，每个表内 ID 递增且跨表唯一；同版本/flags 表不得重复；所有非零属性索引须落在 `ipco` 中，包括次要 item 的索引 |
| 主图属性 | 主图须关联唯一 `ispe` 和 `av1C`；检查正尺寸、配置头和位深标志；如果关联了 `pixi`，其通道数与各通道位深须与 `av1C` 一致。尺寸是存储画布尺寸，不应用旋转或裁剪属性 |
| 数据来源 | `iloc` 条目须引用已声明 item 且不得重复，主图须有位置；解析 base + extent offset，显式正长度区间须完整落在单个 `mdat` 载荷中，或相对当前 `meta/idat` 载荷。允许多段和跨 item 共享区间，不把共享内容误判为重叠错误 |
| 有界读取 | 先按父盒边界检查盒长和字段宽度，再做偏移运算；扩展盒长与字段值超过有符号 Int64 范围明确返回不支持。大文件的末尾 `mdat` 载荷无需读入即可判断声明区间是否越界 |

公开 API（完整类型见 `pkg.generated.mbti`）：

```moonbit
// prefix 是完整文件的前缀，file_size 必须来自实际文件大小。
inspect_avif_structure(prefix, file_size) // Result[AvifStructure, AvifDiagnostic]
inspect_avif_file(path)                  // 异步，读取并调用同一核心
```

成功结果包含主图 ID、尺寸、声明 item 数和各数据区间的绝对偏移/长度/来源。失败返回首个诊断的 `code`、`box_type`、绝对字节 `offset`、可确定时的 `item_id` 和说明；`UNSUPPORTED_*`、`LIMIT_*` 表示超出本实现范围，不能据此断言文件违反规范。扫描入口 `scan_assets` 在 AVIF 项上使用此核心，并将诊断写入现有报告，例如 `AVIF[EXTENT_NOT_IN_MDAT] box=iloc offset=113 item=1`。旧 `avif_dimensions` 及 `init` 的尺寸草稿路径继续只提取尺寸，不提供结构验证保证。

**支持范围与上限：** `avif` 主品牌或兼容品牌；`meta` v0、`pitm` v0/1、`iinf` v0/1、`infe` v2/3、`ipma` v0/1 的 7/15 位属性索引、`iloc` v0/1/2 的 0/4/8 字节字段。最多读取 4 MiB 前缀、访问 4096 个盒、声明 256 个 item、处理总计各 4096 项属性关联和数据区间；只遍历固定层级的已知容器。所有必需元数据和完整顶层盒头（包括 UUID user type）必须在前缀中，末尾 `mdat` 载荷可以超出前缀；`size=0` 仅允许用于顶层末盒，不能用于嵌套盒。超限会明确拒绝，不能当作“没发现错误”。文件入口检查读取前后文件大小，不能检测同大小并发改写；调用者应提供稳定文件。

**不支持或未验证：** 仅有 `avis` 的图像序列、grid/其他派生主图、外部数据源、受保护 item、construction method 2、非零 extent index、隐含/零长度数据区间；AV1 OBU 和像素解码、配置与实际码流/尺寸的一致性、颜色/旋转/裁剪语义、完整 `hdlr`/`iref`/MIAF 规则和非主图属性语义。非主图可以没有 `iloc`，但若有条目就检查其引用和数据范围；未知元数据和属性载荷只检查盒边界，不保证其语义（包括 essential 属性）。因此结构检查通过不等于图像能够解码或视觉验收通过。上层内容探测与纯结构入口均按有效 `ftyp` 边界识别兼容品牌；内容探测把 `avif`/`avis` 识别为 AVIF 家族，结构扫描仍要求 `avif` 静态图像品牌。文件格式探测通常读取前 4 KiB，较长 `ftyp` 在 4 MiB 上限内补读完整盒；截断或超限不会凭盒外字节识别为 AVIF。

**复现行为差别：** `moon test --target native` 运行版本库中的结构夹具回归，证明若只破坏 item 声明或数据偏移，旧尺寸接口仍返回 640×360，而结构入口明确失败。合成夹具仅含不透明数据，不宣称可以解码；`moon run --target native scripts/cli_smoke.mbtx` 则使用仓库真实 `examples/formats/assets/hero.avif`，以及每次只改一个字段的三种变异，断言正常文件退出 0、变异文件退出 1，且 JSON/HTML 含精确定位诊断。跨包 `examples/library_consumer` 也消费公开结构入口。

## 生态调研与复用取舍

本项目按实际职责比较相邻实现，并复用可直接替代的通用算法：

| 项目/组件 | 已有能力 | 与片盒点检的关系与取舍 |
|---|---|---|
| [Pillow](https://pillow.readthedocs.io/en/stable/handbook/tutorial.html) | `Image.open()` 识别图像并提供尺寸、格式等属性；完整产品也支持像素解码和编辑 | 借鉴“先读格式与元数据”的使用流程；不移植 Python 实现，也不引入完整像素解码，因为本项目只做交付规格预检 |
| [mizchi/image](https://mooncakes.io/docs/mizchi/image) | PNG/BMP/JPEG 解码与编码，以及部分格式编码、缩放；解码结果为 RGBA 像素数据 | 面向编解码和图像处理。使用它获取尺寸会进入解码路径；本项目读取交付所需的容器元数据，并为格式差异做受限解析 |
| [gmlewis/moonbit-image](https://github.com/gmlewis/moonbit-image) | 基于 Go `image` 的简单 MoonBit 图像表示 | 面向图像数据表示；没有本项目需要的素材清单、目录验收与报告流程 |
| [hanbings/fluorescence](https://github.com/hanbings/fluorescence) | 仓库说明了 MoonBit BMP/PNG 读取及图像模糊、取色等能力 | 覆盖部分格式与图像处理，不包含本项目的素材包验收流程；不将其描述为没有图像读取能力 |
| [gmlewis/crc32](https://mooncakes.io/docs/gmlewis/crc32) / [moonbitlang/x/crypto](https://github.com/moonbitlang/x/tree/main/crypto) | CRC-32 与 SHA-256 通用算法 | 项目直接依赖前者验证 PNG CRC，依赖后者计算内容指纹，不重复实现哈希算法 |

片盒点检的复用单位是规格清单、目录对照与可归档报告，图像元数据检查是其中的可选能力。表中调研对象不代表合作方或采用方；本仓库没有提供 posterkit 或 MoonBitMark 的接入验证，不将它们列为已验证的消费端。

## 快速开始

需要已安装 [MoonBit 工具链](https://www.moonbitlang.com/download/) 与可联网下载项目依赖的环境。本 CLI 使用主机文件系统，当前运行目标为 `native`（仓库已将其设为默认目标）。在仓库根目录运行：

```sh
moon check --target native
moon test
moon run --target native cmd/main -- examples/clean/media-pack.json examples/clean/assets --output report
```

命令会在 `report/` 下生成 `report.html` 和 `report.json`。打开 `report/report.html` 查看视觉报告。CLI 会先确认清单是文件、素材输入是目录；输入路径或清单有问题时给出错误并以非零状态退出。点检完成后，通过时退出码为 `0`；发现素材不合格时仍会先保存两种报告，再返回非零状态，适合接入 CI。

用 `init` 子命令从已有资源目录生成一份起步清单：所有普通文件都会生成路径和容量约束，受支持且能读取尺寸的图片还会附带宽高；`max_bytes` 通常默认为实际大小的两倍、至少 1 KiB，受清单整数范围限制。超过该范围的文件会列出并跳过。生成结果只是待人工核对的草稿，不会替代交付规范：

```sh
moon run --target native cmd/main -- init examples/formats/assets --output media-pack.json
```

生成的清单写入 `media-pack.json`；若该路径已存在会拒绝覆盖，避免破坏手工修改过的清单。起步清单只包含自动读取的宽高和大小上限，`label`、`aspect`、`expected_sha256` 等字段需要人工按交付要求补充。

生成器会转义文件名中的引号、反斜线及全部 `U+0000–U+001F` 控制字符：退格、换页、换行、回车、制表符分别写为 `\b`、`\f`、`\n`、`\r`、`\t`，其余写为 `\u00xx`；中文和 emoji 保持原样。例如，在允许控制字符文件名的文件系统上，`说明` 与 `.txt` 之间含有 `U+001F` 的文件名会生成以下清单项，解析后仍保留原字符：

```json
{ "file": "说明\u001f.txt", "max_bytes": 1024 }
```

转义不改变路径安全规则或操作系统的文件名限制。`manifest.mbt` 中的测试不创建特殊文件名，直接覆盖全部 32 个控制字符的转义及 JSON 解析往返，并核对有、无图片尺寸的清单项，Windows 上也可运行。

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

核心能力由 MoonBit 库提供，CLI 是它的薄消费端。当前复用验证使用仓库内独立包；Mooncakes 发布及从注册表安装的验证安排在验收阶段，尚不作为已完成的复用证据。

仓库附有独立 MoonBit 包作为消费端示例：[`examples/library_consumer`](examples/library_consumer)。它导入本模块，用清单校验一份非图像 `release-notes.txt`，调用 `scan_assets` 并将 HTML/JSON 报告写入 `_build/library-consumer/`。该样例展示通用文件规则不依赖图像解析；它验证独立包的公开 API 调用路径，不代表外部项目采用或用户反馈。仓库根目录执行：

```sh
moon run --target native examples/library_consumer
```

示例可在同一检出目录重复执行，更新两份报告；CLI 回归脚本连续运行两次并核对报告，该脚本由 Ubuntu 与 Windows CI 执行，覆盖输出目录已存在的情况。

在 `moon.pkg` 中引入并起别名：

```moonbit
import {
  "hxiuzheng/media-pack-audit" @audit,
}
```

公开 API 概览（不解码像素；目录扫描中的哈希与 PNG 结构检查可能读取完整文件）：

- 尺寸解析：`png_dimensions` / `jpeg_dimensions` / `webp_dimensions` / `gif_dimensions` / `bmp_dimensions` / `tiff_dimensions` / `svg_dimensions` / `avif_dimensions` / `jp2_dimensions` / `ico_dimensions` / `psd_dimensions`，均接收 `Bytes` 返回 `(Int32, Int32)?`；
- 内容格式识别：`detect_content_format(bytes)` 按文件头返回 `ImageFormat?`，`format_name(format)` 取规范小写名；
- 清单读取与校验：`parse_manifest_json(text)` 拒绝重复键、未知字段和无效规格，返回 `Manifest` 或抛出 `ManifestParseError`；`scan_assets(asset_dir, manifest, manifest_sha256)` 返回 `AuditReport`；
- 报告生成：`render_html(report)` 生成中文 HTML，`AuditReport` 实现 `ToJson` 生成机器可读 JSON；
- 起步清单：`scaffold_manifest(asset_dir)` 从目录生成 `ScaffoldResult`；
- 通用工具：`sha256_bytes`、`parse_aspect` / `matches_aspect`、`closest_match`、`html_escape`。

调用者也可以直接构造 `Manifest` / `AssetSpec`。`scan_assets` 会校验类型化规格：非正 `min_bytes`、下限高于 `max_bytes`、无效摘要、无效比例或未知格式均使对应项成为 `FAIL`，保留文件名与标签，且不读取该项文件内容或计算其摘要；不会忽略非法规则后返回通过。JSON 入口对相同约束抛出 `ManifestParseError`，其中下限高于上限也会在扫描前拒绝。

独立消费包的受控回归覆盖直接构造的非法规格、HTML/JSON 失败报告、普通文本的精确大小与大写摘要，以及合法 SVG 尺寸/比例/格式约束。复现命令为 `moon test --target native -p hxiuzheng/media-pack-audit/examples/library_consumer`；这些夹具证明公开接口行为，不是维护者真实素材试用或外部采用记录。

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

每项都需要 `file` 和 `max_bytes`；可选 `label` 用于写明用途，并显示在 HTML/JSON 报告中。任意普通文件都可使用 `max_bytes`、`min_bytes` 和 `expected_sha256` 校验；`width` 与 `height` 必须成对填写，仅适用于受支持图像，`aspect` 与 `format` 也是图像约束。当前版本拒绝未识别字段（例如把 `max_bytes` 错拼成 `max_byts`），避免忽略用户写下的要求。已填写的尺寸、单项大小上限及总容量上限必须是正整数，小数会直接报错而不会被截断。`file` 可写为目录内相对路径，例如 `social/cover.jpeg`；使用 `/` 作为分隔符，不得使用绝对路径、反斜线或 `..` 路径段。

非图像文件示例：

```json
{ "assets": [{ "file": "release-notes.txt", "label": "发布说明", "max_bytes": 2048, "min_bytes": 20 }] }
```

省略 `width`/`height` 表示不要求特定尺寸；检查器仍会对扩展名或文件头可识别的图片读取元数据、检查可支持的容器规则，并报告扩展名与内容不符。普通非图像文件无需图像字段；若清单提供图像尺寸或比例，素材必须能识别为受支持的图像格式。

大小约束字段使用正 `Int32`，单个上限最多为 2,147,483,647 bytes；`init` 会跳过无法在该范围内生成预算的文件并列出路径。容量累计使用 `Int64`，但可填写的整包预算也受上述字段范围限制。未登记的非图像文件会使点检失败，当前不为其计算摘要；因此潜在重复提示不覆盖这些文件。

顶层可选填写正整数 `max_total_bytes` 限制整个素材目录树的容量。工具会递归累加其中所有普通文件（图片和非图片均计入），忽略符号链接，并在 JSON/HTML 报告中添加 `<package>` 汇总项；未设置时不执行总容量检查。

素材项可选填写 expected_sha256，值必须是 64 位十六进制 SHA-256（接受大小写混用）。工具用文件指纹与之比较；不匹配会使素材项失败并在报告中列出清单期望值。若文件超过 max_bytes，哈希计算和预期值比较都会跳过，报告会明确说明。在 Windows PowerShell 中可运行 `Get-FileHash .\poster.png -Algorithm SHA256`，将 Hash 列复制到清单；素材重新导出后应更新摘要。预期摘要用于核对内容，不是数字签名或来源认证。

素材项可选填写 `aspect`，值为 `W:H` 形式的正整数比例（例如 `16:9`、`4:3`、`1:1`）。工具用整数交叉相乘核对实际宽高是否精确符合该比例；例如要求 16:9 时，1920×1080 通过，而 1200×630（约 1.905:1）不通过。这是精确比例校验，不是近似判断；尺寸本身不满足精确比例时请勿填写该字段。

素材项可选填写 `min_bytes`，值为不大于 `max_bytes` 的正整数，表示交付文件不得小于该体积。工具按文件头识别实际图片格式，与扩展名不一致时报告“扩展名与内容不符”；也可选填写 `format` 断言文件的内容格式，值接受 `png`、`jpeg`/`jpg`、`webp`、`gif`、`bmp`、`tiff`/`tif`、`svg`、`avif`、`jp2`、`ico`/`cur`、`psd`（大小写不敏感），与文件头识别出的实际格式不一致时判为失败。格式识别只读文件头，不解码像素。

## 项目结构

- `image.mbt`、`webp.mbt`、`svg.mbt`、`avif.mbt`、`jp2.mbt`、`ico.mbt`、`psd.mbt`：清单类型、各格式尺寸解析与素材点检逻辑。
- `isobmff.mbt`：AVIF 与 JPEG 2000 共用的 ISO-BMFF 盒结构解析器。
- `avif_structure.mbt`、`avif_structure_file.mbt`：有界 AVIF 结构一致性核心和文件入口；与仅取尺寸的旧接口分开。
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

本项目刻意把范围控制在可解释、可演示、可测试的一条链路：清单输入 → 文件点检 → HTML/JSON 交付报告。仓库依赖版本记录在 `moon.mod`；复现时先记录实际工具版本，再执行以下验证，其他工具链版本也须以检查结果为准：

```sh
moon version --all
moon update
moon fmt --check
moon fmt --check scripts/cli_smoke.mbtx
moon check --target native --deny-warn
moon test --target native
moon run --target native examples/library_consumer
moon run --target native scripts/cli_smoke.mbtx
```

2026-10-17 本地复核使用 MoonBit `0.1.20261012 (748b63c)`：WSL Ubuntu / GCC 15.2 下无警告静态检查、59 项原生测试、独立库消费示例和 CLI 回归均通过。提交 `163a9d3` 的 [GitHub Actions #39006864786](https://github.com/hxiuzheng/media-pack-audit/actions/runs/39006864786) 已在 Ubuntu 与 Windows 两个 job 通过格式检查、无警告检查、59 项原生测试、独立消费示例（1 项通过）及完整 CLI 回归；Windows 原生运行的依据为远端 CI，不是本机运行。

2026-10-20 20:13 复核的起点是提交 `1d0f60a`，其 [GitHub Actions #39408423330](https://github.com/hxiuzheng/media-pack-audit/actions/runs/39408423330) 在 Ubuntu/Windows 均以 Moon `0.1.20261016` 完成格式、无警告类型检查、75/75 原生测试、独立库示例及完整 CLI 回归。最终复核另发现并修复 UUID 盒头前缀不完整、嵌套盒 size=0 两项遗漏，加入版本库单测和真实 CLI 报告定位回归；修复后原生测试为 77/77。新提交的远端结果须核对其自身 Actions，前述 75 项记录仅属于所标注提交。

早期工具链可能无法解析当前依赖；工具链兼容或依赖解析失败不能算作测试通过。仓库的 Ubuntu 与 Windows CI 配置均包含原生检查、独立库消费示例和 CLI 回归；配置存在本身不代表某次远端运行已通过。

2026-10-20 的 Windows 格式失败在与 CI 相同的 Moon `0.1.20261016` / moonc `0.10.16` 下复现：CRLF 检出会触发格式差异，随后 Git 对 formatter 的 `\\?\` 路径报文件不存在；同一文件用普通路径可以读取。仓库 `.gitattributes` 对 Moon 源码、脚本、生成接口和包配置固定使用 LF，以覆盖 Windows `core.autocrlf=true`。临时的干净检出对照中，应用该规则后项目与脚本的 `moon fmt --check` 均通过；人为放入未格式化源码仍会失败。CI 的检查步骤与失败条件保留，无需修改工作流；最终远端结果以对应提交的 Actions 为准。

后续迭代优先做更好的错误提示、真实项目清单模板和测试覆盖，再考虑更多格式。复用边界与相邻实现的取舍见上文「生态调研与复用取舍」；预期用途及其验证依据见「三个可验证的预期使用场景」。

## 人工主导、AI 辅助说明

项目目标和约束由参赛者提出。本轮 Codex 参与了 AVIF 结构核心实现、兼容品牌修复、回归测试、CI 诊断与文档修订，自动执行的验证记录见开发记录。项目方向、范围取舍、公开声明和最终提交由参赛者本人负责；本轮源码理解与公开声明的本人复核仍需本人确认，自动测试和 AI 审查不能代替该确认。

AI 生成的建议不自动视为成果：每项改动都必须由参赛者检查源码、运行相关测试并理解其限制；未完成人工复核的改动不得作为最终参赛成果。仓库保留开发记录中的 AI 辅助披露，不改写历史来伪造纯人工作者。

## License

项目代码采用 Apache-2.0，详见 [LICENSE](LICENSE)。GIF 是 CompuServe Incorporated 的服务标记；尺寸字段按 [GIF89a 规范](https://www.w3.org/Graphics/GIF/spec-gif89a.txt)读取。
