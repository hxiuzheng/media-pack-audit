# 仓库范围与申报核心对应事实

本文是仓库技术说明和参赛者撰写正式申报材料时可核对的事实，不是替参赛者撰写或提交的申报书。正式申报书仍须由参赛者本人按大赛章程撰写。仓库文档、源码和自动验证能说明实现范围，不能证明评审已经接受其独立项目定位。

## 产品用途与可核验的自有核心候选

产品用途是对一个交付文件包执行预检。调用者给出清单和目录，工具核对文件是否齐全、路径是否安全、文件是否满足格式和资源约束，并生成诊断结果。

当前仓库可支持参赛者确认是否纳入本次申报的自有技术核心是：**在 MoonBit 中实现一个有资源上限、可独立调用的直接静态 AVIF 主图元数据关系检查器。** 它不需要外部预期尺寸、摘要或规则清单来推导文件内部关系；它读取主图声明、item 声明、属性关联和数据位置，将这些声明解析成有序属性证据及绝对数据区间，并返回成功的受支持子集结果或包含字节偏移的诊断。清单扫描器把此结果集成到文件包预检中。现有正式申报书尚未写清这项核心；不能从本文推定它已纳入组委会收到的申报范围。

因此，整包检查是产品使用场景；如参赛者选择以当前仓库回应此次核心深度意见，能对应的自有实现证据是 AVIF 关系解析与判定。清单逐项比较、报告、CLI 或 CI 单独都不作为净核心深度的证据。此定位有明确格式边界，不等同于宣称 AVIF 解析器覆盖全部媒体文件；大赛章程对过窄选题的建议以及类似 MoonBit 项目的独立建设理由，仍须由参赛者本人结合正式申报说明。

## 扣除通用和可复用工作后，剩余的语义处理

| 不计入自有核心深度的部分 | 来源或用途 |
|---|---|
| CRC-32、SHA-256、异步文件 I/O、JSON | CRC-32、SHA-256 和异步 I/O 由锁定依赖提供；JSON 使用 MoonBit 标准库。本项目只调用这些通用能力，不把算法或序列化算作新增核心 |
| 通用清单读取、路径安全、目录遍历、大小/摘要/宽高比较、汇总和报告 | 文件包产品的输入、规则集成和输出；外部规则的逐项比较不是本次 AVIF 自有语义贡献 |
| MoonBit 工具链、格式检查、接口生成、CI 和 CLI 包装 | 交付和维护路径；有助于复现，但不替代领域实现 |
| 通用 ISO-BMFF 盒边界读取 | 解析基础设施；单独读出盒头或宽高不等于关系校验 |

扣除以上部分后，仓库自行负责的 AVIF 语义链如下：

| 自有处理 | 约束关系和结果 | 版本库中的最小反例 |
|---|---|---|
| 主图与 item 声明 | `pitm` 主图必须对应已声明的 `iinf/infe` item，item 引用不可悬空 | 真实样例只改声明 ID：旧 `avif_dimensions` 仍可返回 `640×360`，新入口报 `UNDECLARED_PRIMARY` 并定位 `pitm` |
| 属性绑定与配置 | `ipma` 索引按 `ipco` 顺序解析；主图需有唯一 `ispe` 和 `av1C`；受支持的 `pixi` 通道数/位深须与所解析的配置字段相符 | 属性索引越界报 `PROPERTY_INDEX`；只改 `pixi` 位深报 `PIXI_DEPTH`。这些错误与主图尺寸字段是否仍可读分别验证 |
| essential 属性范围 | 保留每项主图属性的索引、实际 fourcc、属性盒偏移及 essential 标志。已解释字段子集为 `ispe`、`av1C`、`pixi`；未解释且标为 essential 的主图属性以 `UNSUPPORTED_ESSENTIAL_PROPERTY` 拒绝，未标 essential 的未知属性保留为 `interpreted=false`。属性索引为 0 时 essential 必须为 0 | `hero.avif` 的 `ipma` 字节偏移 266 从 `0x04` 改为 `0x84`，只增加 essential 标志，返回 `UNSUPPORTED_ESSENTIAL_PROPERTY`、`box=ipma`、`offset=266`、`item=1`；旧尺寸读取仍返回 `640×360`。单独把 ispe 关联字节 263 改为 `0x80` 则返回 `PROPERTY_ESSENTIAL_ZERO`；该改动同时移除了 ispe 关联，旧尺寸读取不可用 |
| 数据位置与来源 | `iloc` 的 base/offset/length 解析成绝对区间；显式正长度的主图数据必须完整落在一个 `mdat` 载荷中，或按支持的 construction method 落在所属 `meta/idat` 载荷中 | 只把真实 AVIF extent 指向 metadata 区域报 `EXTENT_NOT_IN_MDAT`，旧尺寸仍可读 |
| 有界输入和诊断 | 在父盒范围内解析已支持的版本/字段宽度，执行有界偏移运算；区分结构错误、不支持的特性和资源上限不足 | 前缀不足时报 `LIMIT_METADATA`；诊断含错误码、盒类型、绝对字节偏移、可确定的 item ID 和说明 |

上述反例由同一真实 `hero.avif` 派生，每例只改一个字段并在内存中执行；输入样例不会被重写。`examples/avif_semantics` 不加载外部清单、摘要、文件包扫描器或 HTML 报告，直接消费公开的纯结构 API 和文件入口，断言结果后生成 `_build/avif-semantics/evidence.json`。完整 CLI smoke 又验证该核心实际进入清单扫描路径。

## API 与结果含义

公开纯函数 `inspect_avif_structure(prefix, file_size)` 接收文件前缀和真实文件大小；调用者须保证前缀确实来自该文件。`inspect_avif_file(path)` 是有界文件入口，读取前缀并调用相同结构解析。成功结果包括：主图 ID、存储画布宽高、声明 item 数、主图属性关联证据及解析出的数据区间。属性证据中的 `interpreted=true` 只表示本项目检查了该属性的文档所述字段子集，不代表完整属性语义或 AV1 数据经过验证。

失败结果是首个结构诊断，不是像素解码结果。`UNSUPPORTED_*` 表示遇到本实现没有支持的格式能力；`LIMIT_*` 表示输入超出读取或工作预算、验证未完成；二者都不能解读为已证明文件违反 AVIF 规范。调用者直接构造公开 `AvifStructure` 结构体字面量时，新增字段 `primary_properties` 需要加入其构造代码；仅读取原结果字段的调用不需要改动。

## 支持范围和硬限制

- 只验证 `avif` 静态图像品牌下的直接 `av01` 主图；`avif` 可为 `ftyp` 主品牌或兼容品牌。内容格式识别家族与结构验证支持范围不是一回事。
- 支持 `meta` v0、`pitm` v0/1、`iinf` v0/1、`infe` v2/3、`ipma` v0/1（7/15 位索引）、`iloc` v0/1/2（0/4/8 字节字段）的已实现字段组合。
- 最多读取文件开头 4 MiB，访问 4096 个盒、声明 256 个 item、处理合计各 4096 项属性关联和数据区间。
- 必需元数据和完整顶层盒头须位于读取前缀内；末尾 `mdat` 载荷可位于前缀之后，仍按真实文件大小验证声明区间。
- 主图属性语义只解释上述 `ispe`、`av1C`、`pixi` 字段子集。次要 item 的属性引用和索引受结构检查，但次要属性的载荷语义不作完整验证；`primary_properties` 只返回主图属性证据。

当前不实现或不验证：AV1 OBU/像素解码、实际码流与 `av1C` 的完整一致性、grid 或其他派生主图、仅序列内容、外部/受保护数据源、construction method 2、非零 extent index、隐含或零长度区间、全部色彩/旋转/裁剪语义、完整 HEIF/MIAF/`iref` 规则、非主图属性载荷语义。检查通过只表示声明关系落在本项目明确支持的子集内，不代表图像可以解码、显示正确或达到完整格式合规。

## 独立复现

在仓库根目录运行：

```sh
moon run --target native examples/avif_semantics
moon test --target native --deny-warn
moon run --target native scripts/cli_smoke.mbtx
```

第一条直接执行 9 个正常、单约束变异和范围上限案例，并生成机器可读证据。第二条运行版本库内结构回归。第三条运行清单扫描、公开库消费及真实 AVIF 包级变异回归。完整正式验收仍以所推送确切提交的 CI 结果为准；单机示例或旧 SHA 的 CI 不替代它。

## 参考来源、依赖和样例

大赛范围按[十月官方页面](https://moonbitlang.github.io/Hackathon2026/)及其链接的[正式章程](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd)理解：[新项目和相近项目要求](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd#LWUCdymbkoJWtQxsIJkcrAqNnFn)、[申报书内容与人工撰写要求](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd#HUC2d43wcoQzNixvIfEcU3NSnFc)、[有效贡献限制](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd#NPxvdCw96okOpoxRqvCcRud8nx8)。章程要求交代至少三个使用场景与核心功能，并说明参考来源、交付边界及与相近项目的关系；它也提醒选题不要缩到只覆盖一个特定格式。这里的 AVIF 范围用于给出本次自有语义实现的可核对证据，产品仍覆盖交付文件包预检；此定位是否构成立项理由由评审决定，申报人须在正式材料里亲自说明独立建设价值。

| 项目 | 用途和关系 | 许可证/范围 |
|---|---|---|
| [AOM AVIF 规范](https://aomediacodec.github.io/av1-avif/) | 核对 AVIF 品牌、主图属性和文件结构字段；规范是实现依据，不是运行依赖 | 本仓库实现的是上文列明的子集 |
| [AOMediaCodec/libavif](https://github.com/AOMediaCodec/libavif) | 只作为公开实现参考，用于交叉核对字段宽度和边界行为；未链接、未调用、未复制其解码器 | 上游仓库声明 BSD-2-Clause；不将其代码并入本项目 |
| [Pillow](https://github.com/python-pillow/Pillow) | 图像功能对照及部分仓库样例生成工具，不是运行依赖；没有把其解码器或代码纳入本项目 | 当前上游声明 MIT-CMU；其能力不计作本项目实现 |
| [MoonBit Notary](https://mooncakes.io/docs/hcjbat/moonbit-notary) | Mooncakes 当前列出 v0.1.0、Apache-2.0；公开说明覆盖电子证据清单、目录扫描/分类、路径与摘要规则、重复材料、批处理、审计记录和报告 | 与本项目的清单驱动文件包检查存在真实重叠，不能把清单、摘要、重复提示或报告当作独立性的依据 |
| [`moonbitlang/async@0.22.1`](https://github.com/moonbitlang/async) | 异步文件 I/O 基础 | Apache-2.0；按锁定依赖版本复用 |
| [`moonbitlang/x@0.5.5`](https://github.com/moonbitlang/x) | SHA-256 通用算法 | Apache-2.0；按锁定依赖版本复用 |
| [`gmlewis/crc32@0.8.18`](https://github.com/gmlewis/moonbit-crc32) | PNG CRC-32 通用算法 | Apache-2.0；按锁定依赖版本复用 |

MoonBit Notary 是最接近文件包工作流的对照对象之一：其公开说明包含清单、目录扫描、路径/摘要/重复项校验，以及证据审计和报告。本仓库同样提供清单驱动检查，因此这一层有重叠。可以从当前源码和回归直接说明的不同点是：片盒点检面向交付素材规格及整包预算，并自行解析 AVIF 的 `pitm → iinf/infe → ipma/ipco → iloc → mdat/idat` 关系；MoonBit Notary 的公开文档未列出这类 AVIF 内部结构检查。文档未列出不等于源码确定不支持，故不作此类排他结论，也不声称仓库由此自动满足独立立项要求。正式申报仍须由参赛者说明具体目标用户、为什么选择独立实现而非复用相邻项目，并把 AVIF 子范围与整个文件包工具的关系写清楚。

本仓库也对照了 [mizchi/image](https://mooncakes.io/docs/mizchi/image)、[gmlewis/moonbit-image](https://github.com/gmlewis/moonbit-image) 和 [hanbings/fluorescence](https://github.com/hanbings/fluorescence) 的公开项目说明。它们涉及图像解码/编码、图像表示或 BMP/PNG 读取和处理；这里不据简介断言其完整功能，也不据此声称不存在 AVIF/元数据方向的重叠。正式申报仍须由参赛者核实相近的 MoonBit 项目并解释独立建设理由。

仓库生成的测试变异只在内存中进行；已有格式样例的来源见[开发记录](development-log.md)。代码与仓库材料按项目 Apache-2.0 许可证分发。本说明不据有限调研声称该核心一定达到立项门槛。

## 申报材料一致性待办

实际申报书根据用户要求保持原样。它目前仍描述旧版本的“仅主图尺寸关联”，写有 60 项测试、Windows 未完成，并称尚未解析图像数据位置；这与当前仓库的有界 item/属性/extent 核心、当前测试和后续 CI 记录不一致。仓库这份事实文档不会自动更新报名表或成为组委会已收到的补充材料。参赛者如决定再次提交，须本人把真实范围、排除项、代码/演示入口及最终同一 SHA 的 CI 链接补入报名信息，并确认自己理解源码及 AI 辅助披露。
