# 开发记录

记录实际完成的改动和验证结果，不追记或拆分此前没有发生的工作。

## 2026-10-29：完成 Mooncakes 发布与注册表消费验证

- 用默认 Moon 环境运行 `moon whoami`，确认账号为 `hxiuzheng`。先发布 `hxiuzheng/media-pack-audit@0.1.0`；随后发现 README 仍把发布写成将来安排，因此更新 GitHub README 的安装/发布事实，并将仅含文档更新的包版本提升到 `0.1.1`。没有修改申报书或 AVIF 源码。
- `moon view hxiuzheng/media-pack-audit@0.1.1 --json` 成功，确认 `0.1.1` 是最新公开版本，许可证为 Apache-2.0；`moon publish` 对 0.1.1 返回 `200 OK`。两个版本均保留在注册表。`moon publish --dry-run` 的服务端返回 `202 Accepted` 并称 dry run 完成，但本机 CLI 随后以退出码 1 输出通用失败，因此不把 dry run 记为通过；实际发布命令和版本查询分别成功。
- 在 `%TEMP%` 的独立消费项目用无版本后缀的 `moon add hxiuzheng/media-pack-audit` 安装，`moon.mod` 锁定到 0.1.1；`moon check --target native` 退出 0，`moon run --target wasm .` 退出 0 并输出 `&lt;`。检查输出有 MoonBit 对新建主包中仅黑盒测试文件的未来兼容提醒。该临时消费包尝试 `moon run --target native .` 时因本机没有 MSVC/Windows SDK 而失败，未称为通过；仓库同一 GitHub 提交的 CI 已覆盖 native 构建和测试。
- GitHub 提交 [`dcb39e6`](https://github.com/hxiuzheng/media-pack-audit/commit/dcb39e63959e39f73bf8afca907eda3a9110301d) 由仓库创建者账号普通推送；[Actions #40813056082](https://github.com/hxiuzheng/media-pack-audit/actions/runs/40813056082) 的 Ubuntu 与 Windows jobs 均通过格式检查、无警告检查、native 构建、原生测试、独立库消费示例和 CLI smoke。README 与版本更新后本地 `moon check --target native --deny-warn`、`moon package --list` 通过。
- 本机 `moon info` 曾把生成接口中的 `Int32` 显示改成 `Int`；确认是工具链生成差异后已恢复 `pkg.generated.mbti`，未纳入提交。注册表安装时符号包下载出现一次超时提醒，但 registry index 更新、包依赖解析、类型检查与 Wasm 运行随后成功。

## 2026-10-24 02:22 阶段：补充相邻 MoonBit 文件包项目对照

- 复核起点为 `9238c3eb171941f72f39b6224bcc76b00ea0ee8f`，`main` 与 `origin/main` 一致且工作区干净；该 SHA 的 Ubuntu/Windows CI 已通过。重新按 Mooncakes 当前条目及其公开 README 核对 [MoonBit Notary](https://mooncakes.io/docs/hcjbat/moonbit-notary)：页面列出 v0.1.0、Apache-2.0，文档描述电子证据清单、目录扫描/分类、路径与摘要规则、重复材料、批处理、审计记录和报告。
- README 与 `docs/core-scope.md` 现明确记录两项目在清单驱动扫描、路径/摘要/重复项处理和报告方面的重叠；对照项目的公开文档未列出 AVIF 内部关系检查，但没有据此推断其源码缺少此功能。MediaPack Audit 可由仓库源码和回归核验的不同点是交付素材规格/整包预算及 `pitm → iinf/infe → ipma/ipco → iloc → mdat/idat` 的有界 AVIF 关系解析。该差异不能单独证明独立项目立项理由。
- 申报书、申报表均按用户要求保持不变。第三次驳回指出正式申报材料未说明扣除可复用能力后的核心工作及 AVIF 与申报范围的关系，因此仓库文档改动没有消除该材料缺口；需参赛者本人处理后才可评估是否重提。
- 本地验证使用 WSL Linux 下 Moon `0.1.20261012` / moonc `0.10.15`：`moon info`、`moon fmt`、项目和 `.mbtx` 格式检查、`moon check --target native --deny-warn` 通过；原生测试 **81/81**、独立库消费示例 **1/1**、AVIF 核心示例 **9 项**、完整 CLI smoke 均通过。Windows 本机缺少 MSVC 与 Windows SDK，未能在本机运行 Windows 原生测试。推送提交 [`ffd12c5`](https://github.com/hxiuzheng/media-pack-audit/commit/ffd12c561f703c6d6fdc40297d0c264a7bd2f3f5) 后，[GitHub Actions #40003733528](https://github.com/hxiuzheng/media-pack-audit/actions/runs/40003733528) 在同一 SHA 的 Ubuntu 与 Windows jobs 均通过格式、无警告检查、原生测试、独立库消费示例和 CLI smoke；Windows Git 的 `git diff --check` 通过。
- 10:11 阶段应核对本次推送的确切 SHA 及 Ubuntu/Windows CI，并再次确认正式申报书仍未覆盖第三次驳回的两项说明；不把仓库增强当成已代替本人更新申报材料。

## 2026-10-23：回应第三次初审意见，明确申报核心映射并补齐 essential 语义

- 本次驳回指出的具体问题是：既有仓库说明重点仍放在清单驱动预检、API 与 CI；申报书没有说明扣除通用能力后哪些自有语义处理支撑项目核心，也没有把新增 AVIF 结构校验对应到本次申报范围。README 与 Pillow 对照因此改为区分产品用途、申报核心和通用集成层，明确清单比较、依赖、扫描和报告不作为净核心深度证明。
- 新增 `docs/core-scope.md`，逐项映射自有处理的主图/item 声明、属性索引与配置、extent 数据来源和有界诊断；列出资源预算、未实现格式能力、参考项目与依赖许可证、仓库运行命令和正式材料中仍需参赛者确认的内容。依据十月官网和章程说明其对新项目定位、人工撰写、核心功能/场景及相近项目理由的要求，不把测试数量或 CI 绿灯说成评审门槛。
- 检查发现属性绑定解析丢弃 essential 标志，真实 `hero.avif` 的主图属性即使 essential 却未被解释仍可能返回结构成功；索引为零且 essential 为真也会被忽略。现在公开结果保留主图属性索引、实际 fourcc、属性盒偏移、essential 与 `interpreted`；零索引 essential 返回 `PROPERTY_ESSENTIAL_ZERO`，未解释的主图 essential 属性返回 `UNSUPPORTED_ESSENTIAL_PROPERTY`。允许 av1C essential 位未置位，因为规范对此为建议而非强制。
- 增加四项结构回归（7/15 位索引、未实现/未知 essential 与非 essential、零索引含/不含 essential、次要 item 零索引、真实 hero 属性映射），并增加独立公开 API 消费示例。示例不读清单或报告，使用 358-byte `hero.avif` 的原始数据及内存变异运行 9 个断言案例；`ipma` 字节 266 从 `0x04` 改为 `0x84` 后，尺寸入口仍给出 640×360，结构 API 定位返回 `ipma/266/item=1`。CLI smoke 继续验证包级报告路径。
- 新增字段 `AvifStructure.primary_properties` 会影响外部直接构造该公开结构体字面量的调用者；生成接口已同步，README 与范围文档说明了迁移影响。只读取旧结果字段的调用者不需要修改。
- 本地验证：Moon `0.1.20261016` / moonc `0.10.16` 的 `moon info`、`moon fmt`、项目与 `.mbtx` 两项 `moon fmt --check`、`moon check --target native --deny-warn` 均通过；脚本先按 formatter 输出修正了一处 tuple 换行。WSL 下项目和脚本格式检查、无警告类型检查、原生测试 **81/81**、独立库消费示例 **1/1**、核心示例 **9/9**、完整 CLI smoke 均通过。Windows 本机没有 MSVC/Windows SDK，未运行 Windows 原生测试；该平台结果由下述同一代码提交的远端 Windows job 验证。
- 正式申报书未修改，当前 SHA-256 仍为 `01a3c859e12eca624cc43e2a3538d83ba776a1e8b6521cc272bed99533962814`。它仍写“仅主图尺寸关联”、60 项测试、未解析图像数据位置和 Windows 未完成；仓库说明不会自动替代报名系统中的申报范围。参赛者若再次提交，须本人更新报名材料并核实相近 MoonBit 项目、源码理解和赛道事实。
- 用户随后授权提交和推送。代码提交 `e9eae3dfc1494f75289c188b19610c18a7fe3d70` 的作者与提交者均为 `hxiuzheng <1739840242@qq.com>`，已推送至 `https://github.com/hxiuzheng/media-pack-audit.git` 的 `main`。对应 [GitHub Actions #39962213891](https://github.com/hxiuzheng/media-pack-audit/actions/runs/39962213891) 在该 SHA 上的 Ubuntu 与 Windows jobs 均通过格式检查、无警告检查、原生测试、独立库消费示例和 CLI smoke；远端 `main` 指向该 SHA，核验时工作区干净。
- 申报书没有修改，SHA-256 仍为 `01a3c859e12eca624cc43e2a3538d83ba776a1e8b6521cc272bed99533962814`。仓库更新不自动更新报名系统材料。

## 2026-10-21：回应第二次初审意见，明确定位并对照 Pillow

- 第二次驳回意见认可清单预检场景、API 与 CI 可行，同时指出核心功能定位不够清楚，并建议完整实现 Pillow 功能集或至少说明差异。按意见选择可核对的对照说明路径；没有把现有 AVIF 元数据子集包装成完整解码器，也没有扩大项目为图像编辑/转码库。
- README 首屏现在先说明验收对象、外部 JSON 规格、目录输入、逐项及整包规则、结构化/HTML/JSON 结果，并说明图像读取是可选扩展。`moon.mod` 项目简介同步明确“依据 JSON 清单验收完整文件包”。
- 新增 `docs/pillow-comparison.md`，从处理对象、输入、图片读取/变换、包级交付规则、报告、AVIF 范围和依赖逐项比较。写明共同点是读取部分图像格式/尺寸信息，职责差异是 Pillow 面向图像解码和处理、片盒点检面向清单驱动整包验收；同时明确调用者可以在 Pillow 周边自行组合清单逻辑，不声称 Pillow 做不到。给出图像处理、包验收及组合使用的选择依据，并引用 Pillow 官方教程、格式和 Image API 文档。
- 全仓风险复查聚焦实际执行边界：清单路径与符号链接处理、图像头/容器读取、AVIF 有界范围、只读扫描、报告输出、公开 API、依赖声明及 CI 步骤。此轮未确认需扩大源码修复的额外阻断问题；本说明不代表形式化安全审计，也不保证无缺陷。
- 验证：CI 同版 Windows 工具链 Moon `0.1.20261016` / moonc `0.10.16` 下 `moon info`、两项格式检查及无警告类型检查通过；生成接口无变化。WSL Ubuntu 原生回归 **77/77** 及完整 CLI smoke 通过；`git diff --check` 通过。Windows 本机无 MSVC/Windows SDK，未运行 Windows 原生测试；应以本次最终提交对应的双平台 CI 为准。
- 申报书未修改。仅根据仓库和 Pillow 官方文档作功能对照，不声称外部采用、性能比较、真实用户试用或评审必然通过。

## 2026-10-20 20:13 阶段：最终复查与盒头边界补修

- 复核起点为 `1d0f60a`，工作区干净，本地 main 与 origin/main 一致；仓库公开、Apache-2.0、所有者 hxiuzheng。逐步核对其 [CI #39408423330](https://github.com/hxiuzheng/media-pack-audit/actions/runs/39408423330)，Ubuntu/Windows 的格式、无警告类型检查、75/75 原生测试、独立库示例、完整 CLI smoke 均真实通过，没有跳过测试。该记录仅适用于所标注 SHA。
- 从自有实现审视本轮增量：公开纯/文件入口按主图声明、属性关联、配置/pixi 和 iloc 数据来源的关系给出结构化诊断；正常/单约束破坏对照证明尺寸可读仍可能结构失败。关键回归、跨包消费及端到端断言均已进入版本库。依赖的 CRC/SHA、规格比较和报告不作为这项核心的新增证据；不把代码行数、测试总数或提交频率作为官方门槛。
- 额外审查发现两项盒头边界遗漏：UUID 的 16-byte user type 可以缺失于所提供前缀而仍被接受；嵌套盒 size=0 会错误延伸到父盒末尾。先加入回归，旧实现为 **75/77**，两项新用例均失败；再要求完整盒头位于前缀内，并只对顶层遍历开放 size=0。规则核对 [libavif stream.c 的 ISO-BMFF 盒头读取](https://github.com/AOMediaCodec/libavif/blob/main/src/stream.c)。保留完整 UUID 及顶层末尾 size-zero mdat 的正常对照；普通/扩展 UUID 盒头的每个不完整前缀均应返回 LIMIT_METADATA。
- CLI smoke 新增真实 hero.avif 的嵌套 pixi size-zero 变异，以及填充到 4 MiB 前缀边缘的 UUID 盒头案例，检查退出码 1、JSON 与 HTML 中的 BOX_SIZE_ZERO/197 和 LIMIT_METADATA/4194296 定位。后者是读取范围不足，不宣称完整文件违反格式规范。未改变报告结构或增加像素解码承诺。
- README 修正了“Codex 只参与重复性草拟”的过窄披露，明确本轮核心、修复、测试、CI 诊断和文档均有 AI 参与；将本轮证据无法核实的“经组委会确认赛道”改为准备申报、由本人核实。新增核心文件映射、边界和已验证 CI 起点说明。十月增量与九月原型分开，未新增外部采用、发布或本人复核完成的声明。

本轮本地验证：Windows 隔离 Moon `0.1.20261016` / moonc `0.10.16` 的 `moon info`、`moon fmt`、脚本格式化、两项格式检查、无警告类型检查均通过；生成 `.mbti` 无变化。WSL Ubuntu / GCC 15.2、Moon `0.1.20261012` 的原生测试 **77/77** 及完整 CLI smoke 均通过，包含所有原有场景、兼容品牌断言、序列拒绝、新增盒头案例和跨包示例重复运行。`git diff --check` 通过。本机未运行 Windows 原生测试；本轮补修的双平台结果须以其最终推送提交的 Actions 核对，不能沿用前阶段 75 项通过记录。

### 重提核对结论与需本人确认项

- 技术项：有界 AVIF 自有核心、可复现反例和可定位诊断已交付；兼容品牌已修复；Windows 格式根因有同版对照及真实双平台 CI 证据。本次补修验证后，本轮检查范围内尚未发现其他已确认的阻断性技术缺陷；这不是对全仓库无缺陷或组委会认可深度的保证。
- 申报书按用户要求保持原样；复查前后 SHA-256 同为 `01a3c859e12eca624cc43e2a3538d83ba776a1e8b6521cc272bed99533962814`。其中三项信息已过时：仅说明主图尺寸关联的整改范围；仍写 60 项测试及 Windows 未完成；仍写未解析图像数据位置。代码现有 iinf/ipma/iloc/mdat/idat 有界一致性核心，测试为 77 项。是否在重提报名信息中补充最终 README、提交和 CI 链接，由参赛者决定；本轮没有代改申报书或提交报名表。
- 必须由本人确认：理解新增核心及不支持项、接受真实 AI 披露、核实赛道沟通事实，并完成源码与公开材料的最终复核。上述均未代签。
- 建议：最终补修提交的双平台流程通过后，从技术整改角度建议重新提交初审；提交前本人应确认上述差异和材料口径。是否达到评审对净核心深度的要求仍由组委会判断。

## 2026-10-20 18:21 阶段：兼容品牌识别与 Windows 格式检查

- 开始时确认 `main`、`origin/main` 均为 16:00 阶段的 `8f4560c`，工作区干净；该提交的 [CI #39392480913](https://github.com/hxiuzheng/media-pack-audit/actions/runs/39392480913) 为 Ubuntu 全部通过、Windows Format 失败。本阶段衔接已有结构核心，没有重复实现或修改申报书。
- 先加入兼容品牌回归，旧代码为 73/74 通过、新用例失败；修复 `content_format.mbt`，按完整 `ftyp` 的实际载荷边界检查主品牌和兼容品牌，支持普通/扩展盒头，不把 minor_version、盒外伪品牌、截断或不完整品牌字段当成 AVIF。文件入口对超过初始 4 KiB 的品牌列表按需补读，最多 4 MiB；相关异步回归验证长品牌表与超限 size-zero 盒。显式导入已有 async 依赖供包内异步测试使用。
- CLI smoke 在真实 `hero.avif` 上只把主品牌改为 `mif1`，保留兼容 `avif`，要求清单的 `format: avif`、640×360 和结构校验均通过；另将主/兼容品牌均改为 `avis`，确认家族识别不被误称为序列支持，结构扫描以 `UNSUPPORTED_BRAND` 拒绝并保留报告定位。
- 隔离下载官方当前工具链，实际版本与 CI 一致：Moon `0.1.20261016 (1af328f)`、moonc `0.10.16+b1a0e846e`。在临时克隆的 CRLF 检出上复现 Windows 格式错误，确认报错的 formatter 输出文件用普通路径及扩展路径均实际存在，而 Git 对 `\\?\` 参数报无法读取；普通路径可以对比。新鲜检出的对照中，将格式输入固定为 LF 后项目和脚本两项 `moon fmt --check` 均退出 0；故意添加未格式化源码仍非零退出。证据限定为本次受控复现，不再将根因猜作并行竞态。
- 新增 `.gitattributes`，对 `*.mbt`、`*.mbtx`、`*.mbti`、`moon.mod`、`moon.pkg` 固定 LF，覆盖 Windows 的 `core.autocrlf=true`；保留 CI 的格式检查和后续所有步骤，没有忽略失败、修改工作流或更换身份来绕过权限。创建者令牌此前缺少 workflow scope，本方案无需该额外权限。
- README 同步当前支持范围和排查依据。`moon info` 由与 CI 相同的新工具链生成，接口将原先的 `Int` 别名显式输出为源码使用的 `Int32`；未增删公开函数、字段或改变其整数宽度。

本阶段由 Codex 辅助实施与验证。Windows 隔离工具链 `0.1.20261016` 的 `moon update`、`moon info`、`moon fmt`、脚本格式化、两项格式检查及 `moon check --target native --deny-warn` 均通过；Windows 本机仍没有可用原生 C 编译器，未把静态检查称为原生运行。WSL Ubuntu / GCC 15.2、Moon `0.1.20261012` 下原生测试 **75/75** 和完整 CLI smoke 均通过，含独立库示例连续两次运行、兼容品牌 format 断言、序列拒绝及既有回归。最终提交的双平台结果待普通推送后核对对应 Actions，不以旧提交的结果代替。

给 20:13 阶段：复核本阶段提交的同一 SHA 是否完成 Ubuntu/Windows 全部 CI 步骤，再核对核心、README、生成接口、演示与申报书既有描述的一致性；申报书仍不修改。本人源码理解、赛道沟通事实及最终重提决定仍需参赛者确认，AI 不代替签字或宣称组委会必然认可。

## 2026-10-20 16:00 阶段：AVIF 有界结构一致性验证核心

- 此前 `pitm/ipma/ispe` 修复只解决主图尺寸选择。本阶段新增独立的 MoonBit 结构校验核心，串联 `pitm → iinf/infe → ipma/ipco → iloc → mdat/idat`，检查主图声明、全部属性引用、主图配置与可选 pixi 位深/通道关系，以及显式数据区间的来源归属。允许多区间、共享区间和 idat 相对地址；在加法前检查父范围，限制 unsigned 64 位值、盒数量、item 数、关联数和区间数。
- 公开纯入口 `inspect_avif_structure(prefix, file_size)` 和异步文件入口 `inspect_avif_file(path)`，返回结构化成功结果或首个可定位诊断。AVIF 扫描项使用新核心，JSON/HTML 保留错误码、盒类型、绝对字节偏移和可确定的 item ID；旧 `avif_dimensions` 与 `init` 尺寸草稿行为保留，不将尺寸提取称为结构验证。
- 版本库回归包含直接 av01 主图、32 位 ID/宽字段、mdat/idat、多段与共享区间、非零 base、跨 mdat 边界、单约束破坏、截断、无符号溢出和资源上限。跨包测试消费公开 API；正常真实 `hero.avif` 及分别只改声明 ID、数据偏移、属性索引的三个变异进入 CLI smoke，断言退出码及 JSON/HTML 精确诊断位置。主图声明或数据偏移破坏后，旧尺寸接口仍可返回 640×360，新核心明确拒绝，证明本阶段超出了尺寸选择修正。
- README 列明自有实现与依赖边界，引用 AOM AVIF 规范并说明支持范围：4 MiB 前缀、4096 个已访问盒、256 个 item、各 4096 项属性关联和数据区间。明确不支持派生主图/序列、外部或保护数据、method 2 等；不检查 AV1 OBU、像素、全部 MIAF/HEIF 规则或非主图属性语义，不能据此声称完整 AVIF 验证。合成结构夹具不宣称可以解码，没有新增外部采用或人工复核记录。

本阶段由 Codex 辅助实施。WSL Ubuntu / GCC 15.2、MoonBit `0.1.20261012 (748b63c)` 下，`moon info`、`moon fmt`、脚本格式化、两项 `moon fmt --check`、`moon check --target native --deny-warn`、`moon test --target native --deny-warn` **73/73** 已通过。完整 CLI smoke 已通过（含 AVIF 正常/三种单字段损坏、跨包示例连续两次运行及既有全部场景）；本机 Windows 原生测试未运行，本次远端 CI 以对应提交的 Actions 实际结果为准，不沿用旧提交通过结果。

给 18:21 阶段：仍须修复上层 `detect_content_format` 忽略兼容品牌的已确认问题，并定位 Windows CI formatter 缺少临时输出文件的失败。新纯结构入口已按 ftyp 盒边界识别兼容 `avif`，但上层探测尚未改动；不要把其测试通过当成扫描 format 断言已修复。工作流未改，创建者现有登录令牌缺少 workflow scope 的限制仍需保留。申报书未修改；当前交付不代表已可重新提交或组委会必然认可核心深度，最终需同一提交的双平台验证和参赛者本人复核。

## 2026-10-20：按初审意见加深 AVIF 主图属性解析

- 组委会本次驳回原文指出：“扣除通用依赖、逐项规格比较和报告后，受限元数据解析所体现的净核心深度不足。”整改聚焦解析器本身，不将依赖、规格比较或报告包装为新增核心。
- AVIF 尺寸读取由“在 `ipco` 中找到第一个 `ispe`”改为按 ISOBMFF 项目关系解析：读取 `pitm` 主 item，解析 `ipma` 中该 item 的属性关联索引，再按一基索引定位 `ipco` 属性。解析期间验证属性盒边界、索引范围、FullBox 版本/标志、关联表长度，并拒绝缺失或多个冲突的主图 `ispe`。
- 增加多 item 回归：缩略图的 `ispe` 先于主图出现时仍应选择主图尺寸；未关联的 `ispe` 不可冒充主图尺寸。原有真实 AVIF 样例继续覆盖完整读取入口。
- 本次类型检查 `moon check --target native --deny-warn` 通过。当前 Windows 环境没有 MSVC/clang-cl 原生链接器，`moon test --target native` 因缺少 Windows C++ Build Tools/Windows SDK 无法启动；原生单测和 CLI smoke 的最终结果以仓库创建者账号触发的 CI 为准，未把未执行的检查写成通过。
- 提交 `adc34e9` 的 [GitHub Actions #39386616392](https://github.com/hxiuzheng/media-pack-audit/actions/runs/39386616392) 中 Ubuntu job 的格式、无警告检查、60 项测试、独立消费示例与完整 CLI smoke 全部通过。Windows job 在 Format 步骤因 MoonBit formatter 临时输出路径不存在而中止，未执行 Windows 原生测试；该步骤在开发机 Windows 本地格式检查通过，但 CI 的 Windows 结果仍待修复其 runner/formatter 问题后补验。

## 2026-10-17：明确十月维护证据并修复消费示例重复运行

- 按 Git 历史梳理维护边界：九月末 `dd8b58b` 已有 11 种图像元数据读取、清单规则、报告和库消费示例；十月 `f7a78a1` 才将尺寸改为可选、纳入普通文件校验与非图像未登记项，随后扩展通用清单生成、修复 JSON 控制字符转义，并在 `163a9d3` 统一直接库调用与 JSON 的约束校验。README 列出对应提交及复现入口，不把九月能力重计为十月新增。
- 补充 `AssetSpec` 尺寸字段的源码迁移要求、正 `Int32` 预算范围、未登记非图像文件不计算摘要的限制；纠正“省略尺寸就只做通用检查”的描述，可识别图片仍会进入元数据与基础容器检查。
- 本地完整复跑首先发现独立消费示例在已有报告目录上调用 `mkdir` 会以退出码 1 结束。现在复用已有普通目录，并拒绝非目录输出路径；CLI 回归脚本连续运行示例两次，核对成功计数、两份报告及 JSON 结果一致性，由既有 Ubuntu 与 Windows CI 执行，覆盖首次运行成功但再次运行失败的缺口。公开 API 签名未变化。
- 将库复用说明限定为当前可复现的仓库内独立包，移除尚未提供安装验证的 Mooncakes 命令；说明 2026-10-31 是十月提交截止，Mooncakes 发布及注册表安装验证安排在后续验收阶段。当前版本的参赛者复核仍待本人完成，本次没有新增人工签字、真实素材试用、外部采用或反馈证据。
- 复查规格校验修复提交 `163a9d3` 的 [GitHub Actions #39006864786](https://github.com/hxiuzheng/media-pack-audit/actions/runs/39006864786)：Ubuntu / Windows 均完成格式检查、无警告检查、59/59 原生测试、独立消费示例（1 项通过）及完整 CLI smoke。此前记录中的 Windows 本机原生测试未运行仍属实；远端 CI 已提供该平台验证，不能混记为本机结果。

本轮由 Codex 辅助修复与验证。使用 MoonBit `0.1.20261012 (748b63c)`、WSL Ubuntu / GCC 15.2：`moon update`、`moon info`、`moon fmt`、`moon fmt --check`、`moon fmt --check scripts/cli_smoke.mbtx`、`moon check --target native --deny-warn`、`moon test --target native --deny-warn`（59/59）均通过；独立消费示例连续两次通过（均为 1 项通过、0 项失败，两份报告写入成功），完整 `moon run --target native scripts/cli_smoke.mbtx` 通过。生成接口无差异，`git diff --check` 通过。本轮本机未运行 Windows 原生测试；本次提交的远端结果以其 GitHub Actions 运行记录为准。

## 2026-10-17：统一直接库调用与 JSON 输入的规格校验

- 修正直接构造 `AssetSpec` 调用 `scan_assets` 时可能忽略非法 `min_bytes`、`aspect` 或 `format` 的问题。类型化规格和 JSON 解码后的规格现在共用校验函数，覆盖正整数大小、成对正尺寸、64 位十六进制摘要、合法比例与受支持格式；无效规格在读取该项文件内容前生成带路径和标签的 `FAIL` 结果。
- 两条调用路径都拒绝 `min_bytes > max_bytes` 的矛盾大小区间；JSON 入口会指出对应的 `assets[index]`。CLI 增加该类清单的退出码 1 和不生成报告的回归，原有最小大小测试改用有效区间，继续验证文件低于下限时保留失败报告。
- 在独立消费包中增加三项公开 API 测试：逐一检查十种非法类型化规格及 HTML/JSON 诊断、核对合法文本的精确大小与大写 SHA-256 以及 SVG 的尺寸/比例/格式规则、检查 JSON 矛盾区间的错误上下文。修复前新增测试为 1 项通过、2 项失败；修复后为 3 项通过。
- 本次输入为受控文本和 SVG 夹具，未新增真实素材试用或外部采用证据。公开接口签名未变化。

验证使用 MoonBit `0.1.20261012 (748b63c)`。WSL Ubuntu / GCC 15.2 下 `moon info`、`moon fmt`、`moon fmt scripts/cli_smoke.mbtx`、`moon check --target native --deny-warn`、`moon test --target native --deny-warn`（59/59）、独立库消费示例及完整 CLI smoke 均通过。Windows 下同版隔离工具链的 `moon info`、两项 `moon fmt --check` 和无警告静态检查通过；Windows 原生测试未运行。`git diff --check` 通过。

## 2026-10-16：让清单脚手架覆盖通用资源包

- `init` 以前只为能识别并读取尺寸的图片生成清单项，普通文档、音频或其他非图像资源会被漏掉；现在每个普通文件都会得到相对路径和容量上限，只有成功读取尺寸的受支持图片会附带宽高。
- 对超过清单整数范围的文件不生成错误预算，而是在结果中明确列出并跳过；生成结果仍是草稿，用户需要按实际交付规范复核并补充标签、最小大小、摘要或其他约束。
- 增加非图像清单项序列化测试和 CLI smoke 场景：从独立库消费示例目录生成清单，再用该清单完成一次点检。清理了过期的九月申报稿和初审准备清单，以及 README 中对旧申报材料的链接。
- 本轮由 Codex 辅助实现和整理；没有新增人工签字或声称外部项目已采用。`moon info`、`moon fmt`、`moon check --target native --deny-warn` 通过，`moon test --target wasm --deny-warn` 为 54/54 通过。当前本机缺少 Native 后端所需的 C 编译器，因此原生测试和调用原生 CLI 的端到端 smoke 尚未在本机运行；需由公开 CI 的 Linux/Windows 原生任务补充验证。

## 2026-09-30：回应初审的可复用库证据与申报材料校正

- 针对组委会认为项目偏向单体应用、可复用性证据不足的意见，强化独立 MoonBit 消费端：示例现在实际写出 HTML/JSON 报告并断言检查结果为 1 项通过；Ubuntu/Windows CI 增加运行该示例的步骤。
- 针对生态复用意见，在申报书中逐项回应 Pillow 的参考范围、MoonBit 图像库的能力边界和实际依赖复用：CRC-32 使用 `gmlewis/crc32`，SHA-256 使用 `moonbitlang/x/crypto`。没有将 Pillow 代码或 Python 包描述成本项目实现/依赖，也没有把仓库内消费示例包装成外部采用证据。
- 修正过时的“全部验收/绝对安全”措辞，区分规格预检与完整图像解码/视觉验收，并说明真实素材试用仅覆盖 4 张 JPEG。
- 将 `464551b` 人工复核签字明确限定为历史版本，并为本轮留下待申报人亲自完成的复核项。Codex 辅助本轮代码与材料修订；未代替申报人勾选或签字。
- 验证过程中，CI 先指出示例中原样重抛异常的 catch-all 不必要；后续运行又指出输出路径字符串未使用 MoonBit 插值语法，及示例只列出一张图片却扫描完整六项素材目录。现已移除冗余 catch-all、修正路径插值，并改用完整通过清单且断言所有已登记素材均通过；不把编译通过误当作端到端通过。
- `moon fmt --check` 与 `git diff --check` 本机通过；本机 `moon check` / `moon test` / `moon info` 因 MoonBit 标准库预构建 `prelude.mi` 缺失和未安装 C 编译器未能完成。代码基准 `ed2a4a1` 的 [GitHub Actions 运行 #36604563580](https://github.com/hxiuzheng/media-pack-audit/actions/runs/36604563580) 已在 Ubuntu/Windows 全部通过格式检查、无警告检查、53 项原生测试、独立消费示例和 CLI smoke。消费示例两端均实际检查 7 项、7 项通过、0 项失败，并打印有效清单摘要及两份报告路径。

## 2026-09-29：支持 SVG/AVIF/JP2/ICO/PSD 五种格式的尺寸预检

- 格式覆盖从 6 种扩到 11 种：新增 SVG、AVIF（HEIF）、JPEG 2000（JP2）、ICO/CUR、PSD 的尺寸读取，均只读容器/头部元数据、不解码像素。
- 新增 `isobmff.mbt` 共享 ISO-BMFF 盒解析器，AVIF 与 JP2 共用同一套尺寸受限、边界校验的盒遍历逻辑；AVIF 沿 `meta→iprp→ipco→ispe` 链读取 ispe 宽高，JP2 沿 `jp2h→ihdr` 读取宽高。SVG 读取 `width`/`height` 属性或回退 `viewBox`，仅接受整数值并忽略 CSS 单位。ICO/CUR 读取首项目录项宽高（0 表示 256）。PSD 读取头部宽高，拒绝 PSB 版本。
- 将内部 `RasterFormat` 重命名为公开的 `ImageFormat`，并暴露 `image_format`（扩展名映射）与 `format_name`（规范名称）两个公开函数，为后续清单脚手架与 `format` 断言复用。
- 新增 `examples/formats` 样例（SVG/AVIF/JP2/ICO/PSD 全部通过），并在 CLI smoke 中加入对应端到端断言。真实样例由 Pillow 生成 AVIF/JP2/ICO，PSD 为最小头样例。
- 已知边界如实保留：SVG 只接受整数宽高、不解析 CSS 继承；ICO/CUR 只读首项目录项；AVIF/JP2 只读容器尺寸盒、不解码码流；PSD 只读头部。这些边界已同步到 README 与项目简介。
- 本轮由 AI 辅助实现与验证；格式盒结构与真实文件的边界（如 Pillow 生成的 AVIF 中 `iprp`/`ipco` 为普通盒而 `meta`/`ispe` 为 FullBox）通过读取真实样例字节确认并修正。

验证命令与结果（Windows 本机，MoonBit `0.1.20260915`）：

```text
moon fmt
moon check --target native --deny-warn
moon test --target native        # 46 passed
moon run --target native scripts/cli_smoke.mbtx
```

以上均通过；`moon info` 已更新 `.mbti` 接口，新增 11 个公开尺寸函数与 `ImageFormat` 枚举。

## 2026-09-29：新增 init 清单脚手架命令与 check/init 子命令

- 将 CLI 从单一命令重构为根命令加 `check`/`init` 两个子命令，根命令设 `default_subcommand="check"` 保持既有调用 `cmd/main -- manifest assets --output ...` 完全兼容。
- 新增库级 `scaffold_manifest`：递归扫描素材目录，复用 `image_format` 与 `read_image_dimensions` 读取每张受支持图片的宽高与大小，生成确定性缩进的起步 `media-pack.json`；`max_bytes` 默认为实际大小两倍（至少 1 KiB），无法读取尺寸的文件被跳过并回传列表。
- `init` 子命令把结果写入 `--output`（默认 `media-pack.json`），若目标已存在则拒绝覆盖并给出中文提示，避免破坏手工修改过的清单。起步清单仅含自动读取的 `file`/`width`/`height`/`max_bytes`，`label`/`aspect`/`expected_sha256` 等需人工补充。
- 新增 `manifest.mbt`（含 `json_escape`、`render_asset_entry` 单测），CLI smoke 增加 init 生成、生成清单回测通过、重复写入拒绝三段端到端断言。
- 本轮由 AI 辅助实现与验证；子命令分发、`default_subcommand` 兼容性与 argparse 的 `Matches` 结构通过阅读 MoonBit core argparse 源码与既有测试确认。

验证命令与结果（Windows 本机，MoonBit `0.1.20260915`）：

```text
moon fmt
moon fmt --check scripts/cli_smoke.mbtx
moon check --target native --deny-warn
moon test --target native        # 48 passed
moon run --target native scripts/cli_smoke.mbtx
```

以上均通过；`moon info` 已更新 `.mbti`，新增公开 `scaffold_manifest` 与 `ScaffoldResult`。

## 2026-09-29：新增 min_bytes/format 字段、内容格式识别与拼写建议

- 素材项新增可选 `min_bytes`（体积下限）与 `format`（内容格式断言）；清单校验在扫描前拒绝小数、非正 `min_bytes` 与非受支持 `format` 名。
- 新增 `content_format.mbt`：按文件头（魔法字节）识别 11 种格式的实际内容，独立于扩展名；`scan_assets` 复用它对文件做内容识别，扩展名与内容不符时给出“扩展名与内容不符（扩展名 X，实际 Y）”的明确提示，`format` 断言则核对实际内容格式与期望值。
- 新增 `suggest.mbt`：用 Levenshtein 编辑距离为未知清单字段给出“你是不是想写 X？”建议，仅当候选足够接近时才提示，避免误导。
- `AssetSpec` 新增 `min_bytes`/`format` 字段（可选，兼容旧清单）；`ImageFormat` 增加 `Eq` 派生以支持格式比较。
- 新增 3 个无效清单样例（小数/零 min_bytes、非法 format），CLI smoke 增加 min_bytes 下限、format 断言通过与不匹配、扩展名与内容不符三段端到端断言；单测增至 53 项。
- 本轮由 AI 辅助实现与验证；内容识别的各格式魔法字节与 AVIF/JP2 盒结构边界通过阅读既有解析器与真实样例字节确认。

验证命令与结果（Windows 本机，MoonBit `0.1.20260915`）：

```text
moon fmt
moon fmt --check scripts/cli_smoke.mbtx
moon check --target native --deny-warn
moon test --target native        # 53 passed
moon run --target native scripts/cli_smoke.mbtx
```

以上均通过；`moon info` 已更新 `.mbti`，新增公开 `detect_content_format`、`canonical_format` 与 `closest_match`。

## 2026-09-26：统一申报材料与人工复核边界

- README、项目简介、初审清单和 CLI 帮助同步到当前的 PNG/JPEG/WebP/GIF/BMP/TIFF 与 `aspect` 功能范围。
- 增加提交前人工复核清单，明确项目方向、验收标准、安全边界和最终公开声明由参赛者本人负责；AI 仅作为查询、草拟、边界枚举、诊断和文档整理助手。
- 保留既有 Codex 辅助披露，不改写 Git 历史来伪造纯人工作者。人工复核清单必须由参赛者本人在提交参赛版本前完成，不把本次自动化检查当作本人签字。
- 补充已知复现条件：当前主分支按 MoonBit `0.1.20260915 (2e1a46d)` 验证；早于该版本的本地工具链可能无法解析当前依赖。
- 本次提交前复核中，`moon fmt --check` 通过；本机 `0.1.20260827` 在依赖下载后缺少标准库预编译产物，且 native 测试环境没有 C 编译器，因此 `moon check`、`moon test` 和 CLI smoke 未在本机完成。该结果已如实记录，不宣称本机全绿。


## 2026-09-26：支持 aspect 宽高比校验

- 素材项新增可选 `aspect` 字段（W:H 形式），用整数交叉相乘精确核对宽高比；清单校验在扫描前拒绝非法比例。
- 新增 `parse_aspect`、`matches_aspect` 及 2 组单元测试；本机 `moon check`、`moon test`（31 passed）与 `moon fmt --check` 均通过。

## 2026-09-26：支持 TIFF 图片尺寸解析

- `RasterFormat` 新增 Tiff，`.tif`/`.tiff` 接入；读取 TIFF 头与 IFD 中的 ImageWidth/ImageLength 标签，支持 II/MM 两种字节序与 SHORT/LONG 两种值类型。
- 新增 3 个单元测试；本机 `moon check`、`moon test`（29 passed）与 `moon fmt --check` 均通过。

## 2026-09-26：支持 BMP 位图尺寸解析

- `RasterFormat` 新增 Bmp，`.bmp` 接入；读取 DIB 头宽高，支持 BITMAPINFOHEADER（及后续头）与旧式 BITMAPCOREHEADER，负高度取绝对值。
- 新增 4 个单元测试；本机 `moon check`、`moon test`（26 passed）与 `moon fmt --check` 均通过。

## 2026-09-26：真实素材试用（本机真实图片）

- 用本机真实 JPEG 图片（数码照片与长截图，共 4 张）做了一次真实素材试用，验证工具对真实（非合成）文件的尺寸、单文件大小与总容量检查。
- 通过用例：4 张真实图片按实际宽高/字节数建立清单，全部通过，退出码 0，耗时约 0.7 秒。
- 受控错误用例：把一张截图的清单宽度写成 1080（实际 1260），工具正确报出“尺寸不匹配”，并报告未列入清单的多余图片，退出码 1。
- 该次记录仅支持“对 4 张真实 JPEG 可读取尺寸并发现受控清单错误”的结论；规格取自文件本身，不代表按外部交付规范完成验收。原试用材料已从当前仓库移除，不将个人文件或机器专属资料作为公开复现证据。

## 2026-09-18：支持清单锁定素材 SHA-256

- 每个素材项可选填写 expected_sha256；CLI 会在扫描前验证其为 64 位十六进制字符串，摘要比对时不区分大小写。
- 文件指纹与预期摘要不一致时，素材项判为失败并列出清单期望值；超过 max_bytes 时继续跳过哈希，并明确标注预期摘要未核对。未设置字段的旧清单保持兼容。
- clean 样例用大写摘要验证匹配。CLI smoke 覆盖摘要不匹配失败、短摘要与非十六进制摘要拒绝，以及超限时跳过预期摘要比对；README 与项目简介同步说明这不是数字签名或来源认证。
- Windows 本机格式检查、moon info、无警告检查、22 项原生测试和 CLI smoke 均通过。提交 e0e098f 的 GitHub Actions 运行 [#35323577758](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35323577758) 中 Ubuntu 与 Windows jobs 均通过格式、无警告检查、22 项原生测试及 CLI smoke。
- 回归仍使用合成夹具；真实素材试用和外部用户反馈仍待完成。

## 2026-09-18：增加素材目录总容量预算

- 清单可选设置 max_total_bytes；点检递归计算素材目录树内所有普通文件的总字节数，图片与非图片都计入，符号链接不计入。报告新增 package 汇总行，显示实际总量与上限，并在超限时将其计入失败数。
- clean 示例使用 100,000 bytes 上限并验证 96,985 bytes 全部通过；CLI smoke 另用嵌套 PNG 与 notes.txt 证明非图片文件计入总量、1-byte 上限会失败。小数与零值预算会在生成报告前拒绝；未设置预算的旧清单继续通过。
- README、项目简介与初审核对表同步更新。本机 Windows 格式检查、moon info、无警告检查、22 项原生测试和可重复 CLI smoke 均通过。
- 提交 602f606 的 GitHub Actions 运行 [#35306416802](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35306416802) 中 Ubuntu 与 Windows jobs 均通过格式、无警告检查、22 项原生测试及 CLI smoke。
- 测试仍使用合成素材；真实素材试用和外部用户反馈仍待完成。

## 2026-09-18：按 EXIF 方向检查 JPEG 显示尺寸

- 发现 JPEG SOF 记录的是文件中存储的宽高；照片若带有旋转或镜像的 EXIF Orientation，显示时的宽高可能不同，直接核对会误报。
- JPEG 尺寸读取现在会解析 APP1 中的 EXIF Orientation，支持小端和大端 TIFF；方向 5–8 时交换宽高。EXIF 缺失、无效或不完整时沿用 SOF 尺寸，不影响普通 JPEG。
- 单元测试覆盖两种字节序和无效方向回退；CLI smoke 使用带 Orientation=6 的合成 JPEG 验证显示为 3×4 并通过。README、项目简介和初审核对项同步说明显示尺寸语义及 4 MiB 元数据扫描边界。
- Windows 本机格式检查、`moon info`、`moon check --target native --deny-warn`、22 项原生测试和 CLI smoke 均通过。提交 `1ce1cb1` 的 [GitHub Actions 运行 #35304023810](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35304023810) 中 Ubuntu 与 Windows jobs 均成功。
- CLI smoke 使用合成 JPEG，不代表真实素材试用；外部用户反馈仍待完成。

## 2026-09-17：拒绝重复 JSON 清单字段

- 复现发现，同一素材对象重复声明 `width` 时，JSON 映射解析会静默保留其中一个值，导致清单含糊却仍可能通过检查。
- CLI 现在在 JSON 映射解码前扫描原文，按解码后的键名检查每个对象；例如 `width` 与转义写法 `\u0077idth` 会识别为同一字段，并在扫描素材、生成报告前报错。
- 新增重复宽度字段 fixture 与端到端 smoke，确认返回非零且不会写报告；同步更新 README 与初审核验项。
- Windows 本机格式检查、`moon info`、`moon check --target native --deny-warn`、20 项原生测试和 CLI smoke 均通过。提交 `b08ea24` 的 [GitHub Actions 运行 #35237939030](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35237939030) 中 Ubuntu 和 Windows jobs 均成功。Windows 原生测试构建输出含依赖库 C 源 `EINVAL` 宏重定义 warning；MoonBit 无警告检查成功，测试通过。
- 此回归仍使用合成清单；真实素材用户试用和外部反馈仍待完成。

## 2026-09-17：在交付报告中显示素材用途标签

- 素材清单支持可选 `label`，用于填写“课程主视觉”“社媒封面”等对交付方有意义的用途名称。
- HTML 与 JSON 检查结果保留标签；HTML 新增“用途”列并通过 HTML 转义函数输出，标签缺省时显示占位符，不影响旧清单。
- clean 示例加入含中文和 `&` 的用途标签，端到端回归核对 JSON 原文与 HTML 转义后的显示；其他未填标签的素材继续通过现有回归。
- README、项目简介和初审测试项同步说明。本机 `moon fmt --check`、`.mbtx` 格式检查、`moon info`、`moon check --target native --deny-warn`、20 项原生测试及 CLI smoke 通过；提交 `4488695` 的 [GitHub Actions 运行 #35236668821](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35236668821) 中 Ubuntu 和 Windows jobs 全部通过。
- 示例仍为合成数据，尚无真实用户试用反馈。

## 2026-09-17：拒绝小数形式的像素与大小规格

- 继续检查清单解析时发现，JSON 的小数 `4.9` 会被 MoonBit `Int` 解码截断成 `4`；实测写入 `4.9 × 3.9` 的规格却得到 `4 × 3` 并通过。
- CLI 现在在转换前验证 `width`、`height`、`max_bytes` 是整数；小数会给出字段路径并停止检查，不会截断成别的要求。
- 新增宽、高和 `max_bytes` 三个小数清单 fixture；端到端 smoke 核对每项报错、非零退出且不生成报告，并重用清理旧报告的辅助流程。
- 本机 `moon fmt --check`、`.mbtx` 格式检查、`moon check --target native --deny-warn`、20 项原生测试和 CLI smoke 通过。提交 `c758fde` 的 [GitHub Actions 运行 #35235721120](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35235721120) 中 Ubuntu、Windows jobs 均通过格式、无警告检查、20 项原生测试及包含三种小数输入的 CLI smoke。
- 回归仍是合成清单，不代表真实素材试用或外部反馈。

## 2026-09-17：拒绝清单中的未知字段

- 实测发现：素材项同时包含正确的 `max_bytes` 和拼错的 `max_byts` 时，JSON 派生解析器会忽略未知键并返回通过，容易让规格约束静默失效。
- CLI 现在只接受根级 `assets` 和素材项 `file`、`width`、`height`、`max_bytes` 四个字段；未知字段在扫描素材前以具体路径报错。
- 新增根级拼写错误与素材项拼写错误两个清单 fixture；端到端 smoke 断言二者返回非零且不生成报告，防止误呈现为通过。
- README、项目简介和初审测试项已同步说明严格字段行为。本机格式、无警告检查、20 项测试及 CLI smoke 通过；提交 `fea1a19` 的 [GitHub Actions 运行 #35234757940](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35234757940) 中 Ubuntu、Windows jobs 均通过格式、无警告检查、20 项原生测试及包含未知字段拒绝的 CLI smoke。
- 回归只使用合成素材；尚无真实用户试用或外部反馈。

## 2026-09-17：在报告中固定所用规格清单

- JSON、HTML 报告和 CLI 摘要现在显示清单原始字节的 SHA-256；归档报告可以用该指纹对应回当时使用的规格文件，空格或换行变化也会产生不同指纹。
- 增加 SHA-256 标准向量单测；端到端 smoke 在运行时读取 `examples/clean/media-pack.json` 的原始字节，核对 JSON、HTML 和 CLI 三处输出，并兼容 Windows 与 Unix 的换行差异。
- 同步 README、项目简介和初审测试清单；明确指纹只是内容标识，不是来源认证或数字签名。
- 本机 Windows 验证：`moon fmt --check`、`.mbtx` 格式检查、`moon info`、`moon check --target native --deny-warn`、`moon test --target native`（20 passed）和 CLI smoke 全部通过。首次远端验证发现写死摘要无法适应平台换行差异，因此改为读取当前 checkout 的原始字节动态核对。提交 `d4f280f` 的 [GitHub Actions 运行 #35232545392](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35232545392) 中 Ubuntu、Windows jobs 均通过格式、无警告检查、20 项原生测试及 CLI smoke。C 运行时依赖仍输出 `EINVAL` 宏重定义 warning；MoonBit 检查无警告且命令成功。
- 新增回归使用仓库合成清单；尚未进行真实素材用户试用，也没有外部反馈。

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
- 收紧当时的一页选题简介，使其与真实实现一致，并对照参赛者此前提到的三个项目说明问题域差别；没有把局部对比表述为全赛事查重保证。
- 新增初审清单，分别列出仓库中已有证据与需要参赛者本人完成的报名、入群、组织方选题确认和真实用户试用；明确这些事项目前没有可验证的完成记录。
- README 加入申报材料入口，避免把“仓库已公开”误写成“已报名或通过审核”。

本轮为材料整理，没有新增代码功能。Windows 本机重跑 `moon fmt --check`、`moon fmt --check scripts/cli_smoke.mbtx`、`moon check --target native --deny-warn`、`moon test --target native`（3 passed）和 CLI smoke 均通过；另外直接运行全通过与发现问题两个 README 演示，分别得到预期退出码 `0` 和 `1`，并生成 HTML / JSON 文件。后续优先取得一名数字媒体同学的真实试用反馈，再据此扩充高价值功能。

## 2026-09-17：增加 JPEG 素材规格预检

- 扩展名支持 `.png`、`.jpg`、`.jpeg`，扩展名比较不区分大小写；完整文件名仍按目录中的实际拼写精确匹配。
- 新增 JPEG marker / SOF 尺寸读取，支持常见 baseline、progressive 等 SOF 类型；JPEG 元数据最多扫描文件开头 4 MiB，不解码整张图。
- 将干净样例扩展为 PNG + 1200×630 JPEG，并在问题样例中加入大写扩展名 `.JPG`，覆盖真实格式识别和大小写行为。
- 新增 JPEG baseline、progressive、损坏 marker / frame length 单元测试；README、项目简介与初审清单同步说明支持范围和边界。
- 本轮由 Codex 辅助实现；JPEG 样例由 Pillow 生成且可正常解码。工具只读取尺寸元数据，不验证像素内容、完整解码或 ICC / 色彩配置；参赛者仍需理解并负责最终实现。

Windows 本机验证通过：`moon fmt --check`、`moon fmt --check scripts/cli_smoke.mbtx`、`moon check --target native --deny-warn`、`moon test --target native`（6 passed）与 `moon run --target native scripts/cli_smoke.mbtx`；Pillow 确认 `.jpeg` 与 `.JPG` 样例均为 1200×630 JPEG。功能提交 `b0a73de` 的 [GitHub Actions 运行 #35209036435](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35209036435) 中 Ubuntu 与 Windows job 均通过。

## 2026-09-17：支持嵌套交付目录并阻止路径越界

- 清单现在可用 `/` 编写嵌套相对路径；扫描目录树并报告嵌套多余图片，路径仍区分大小写。
- 拒绝绝对路径、反斜线、盘符冒号、空路径段和 `.` / `..`，不遍历符号链接目录；预期文件若是符号链接，不会被当作普通素材通过。
- 将真实 JPEG fixture 放入 `social/`，并把问题样例中的额外 JPEG 放入 `exports/`；新增 `../` 越界清单回归和路径拼接单测。
- README 和演示命令明确使用 `native` 目标；项目依赖的文件系统打开/类型查询 API 当前不支持 Wasm / JS 组合目标，因此没有宣称多后端支持。
- 本轮由 Codex 辅助实现，fixture 仍是合成文件；尚无真实用户试用或组织方选题确认记录。

Windows 本机验证通过：`moon fmt --check`、`moon fmt --check scripts/cli_smoke.mbtx`、`moon check --target native --deny-warn`、`moon test --target native` 和默认 `moon test`（均 8 passed）、CLI smoke，以及 README 通过/失败演示（退出码分别为 `0` / `1`）。功能提交 `241f1d1` 的 [GitHub Actions 运行 #35210585186](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35210585186) 中 Ubuntu 与 Windows job 均通过。

## 2026-09-17：增加 GIF 画布尺寸预检

- 扩展名新增 `.gif`（大小写不敏感）；从 GIF87a / GIF89a 头读取逻辑屏幕宽高，并纳入文件大小、清单尺寸和额外图片检查。
- 新增两个版本的尺寸解析及损坏、零宽和短头测试；干净样例加入 320×180 两帧 GIF，失败样例加入大写 `.GIF` 多余文件。
- 明确工具只读 GIF 画布尺寸，不解码帧像素、不核验帧数或播放时序；字段依据 [W3C 发布的 GIF89a 规范](https://www.w3.org/Graphics/GIF/spec-gif89a.txt)。README 同时记录 CompuServe 服务标记。
- 本轮由 Codex 辅助实现，GIF fixture 是合成素材；没有外部用户反馈，不能据此声称完成真实用户试用。

Windows 本机验证通过：`moon fmt --check`、`moon fmt --check scripts/cli_smoke.mbtx`、`moon check --target native --deny-warn`、`moon test --target native` 和默认 `moon test`（均 10 passed）、CLI smoke，以及直接 GIF 演示（清单 GIF 320×180 通过、大写 `.GIF` 额外素材被发现）。功能提交 `c35158b` 的 [GitHub Actions 运行 #35211397433](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35211397433) 中 Ubuntu 与 Windows job 均通过。

## 2026-09-17：为错误类型的 CLI 输入提供清楚提示

- CLI 在读取清单和扫描目录前，先验证清单是普通文件、素材输入是目录；误传目录或文件时返回具体中文提示，不进入底层 JSON 读取或目录遍历。
- 新增两个端到端错误输入场景，分别把目录作为清单、把文件作为素材目录，断言退出码与用户提示。
- 本轮由 Codex 辅助实现；没有改变素材点检范围，也没有外部用户试用记录。

Windows 本机验证通过：`moon fmt --check`、`moon fmt --check scripts/cli_smoke.mbtx`、`moon check --target native --deny-warn`、`moon test --target native`（10 passed）和 CLI smoke。功能提交 `2a8ce2a` 的 [GitHub Actions 运行 #35212045289](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35212045289) 中 Ubuntu 与 Windows job 均通过。

## 2026-09-17：拒绝 PNG IHDR 校验和损坏的素材

- 修正此前只读 PNG 尺寸字段、但没有核对 IHDR CRC 的漏检：现在校验 IHDR 块 CRC-32/ISO-HDLC，头部字段受损时不能以尺寸正确通过。
- 用 `123456789` 标准向量测试 CRC 实现；单测包含 CRC 正确与单字节损坏的 IHDR，端到端 smoke 则运行 CLI 并断言失败报告会保留具体格式错误。
- 更新 README、项目简介和初审清单，明确只校验 IHDR 的 CRC；后续 PNG 块和图像压缩数据仍未做完整性校验，也不解码像素。
- 本轮 Codex 辅助实现，测试夹具为合成数据；没有外部用户试用或新增用户反馈记录。

Windows 本机验证通过：`moon fmt --check`、`moon fmt --check scripts/cli_smoke.mbtx`、`moon info`、`moon check --target native --deny-warn`、`moon test --target native`（12 passed）和 `moon run --target native scripts/cli_smoke.mbtx`。提交 `31b8a61` 的 [GitHub Actions 运行 #35213038689](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35213038689) 中 Ubuntu 与 Windows job 均成功。

## 2026-09-17：按 PNG 规范校验 IHDR 字段

- 在 CRC 校验之外，补上位深与颜色类型的合法组合、压缩方法、过滤方法和交错方法校验，避免 CRC 正确但头字段无效的 PNG 被判为可用。
- 参考 [W3C PNG 规范](https://www.w3.org/TR/png-3/)的 IHDR 定义；增加合法/非法字段组合单测，以及“非法位深但 CRC 正确”的 PNG 与损坏 CRC 样例端到端 CLI 回归。
- 将 smoke 临时目录改为可重复运行；本机连续运行两次均通过。
- 本轮使用 Codex 辅助实现与核对规范；新增样例均为合成数据，没有外部用户试用或反馈。

本机 `moon fmt --check`、`.mbtx` 格式检查、`moon info`、`moon check --target native --deny-warn` 均通过；`moon test --target native` 为 14 passed。提交 `af093bd` 的 [GitHub Actions 运行 #35213747460](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35213747460) 最初检查时 Windows job 尚未完成，后续复核确认 Ubuntu 与 Windows 两个 job 均成功。

## 2026-09-17：校验 PNG 全部块的 CRC 与基本结构

- PNG 检查现在按最多 64 KiB 一块流式读取，不把大型 IDAT 数据整体载入内存；校验每个 chunk 的类型格式、声明长度边界和 CRC，并要求 IHDR 位于首块、至少存在一个连续 IDAT 序列、IEND 长度为零且位于文件末尾。
- CRC 更新改用 nibble lookup，避免每个字节执行八轮位运算；既有 `123456789` CRC 标准向量仍由单元测试覆盖。
- CLI smoke 新增“只有合法 IHDR 的截断文件”和“IDAT CRC 错误”案例。README、项目简介和初审清单明确说明：当前验证 PNG 容器基本结构及 CRC，不等于检查所有块的语义，也不解压或解码像素。
- 本轮使用 Codex 辅助实现和验证；新回归文件均为合成样例，没有外部用户试用或反馈记录。

本机 Windows 验证：`moon fmt`、`moon info`、`moon check --target native --deny-warn` 均通过；`moon test --target native` 为 14 passed；CLI smoke 通过，检查损坏 IHDR、非法 IHDR 字段、缺失图像数据块和 IDAT CRC 错误均得到非零失败报告。编译异步文件系统依赖时 MSVC 输出 `EINVAL` 宏重定义警告，但以上命令均以退出码 0 完成。提交 `b79e37a` 的 [GitHub Actions 运行 #35215623739](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35215623739) 中 Ubuntu 和 Windows job 均成功，包含格式、无警告检查、原生测试及 CLI smoke。

## 2026-09-17：扩展 PNG 容器边界回归

- CLI smoke 增加 chunk 声明长度超出文件范围、包含 IDAT 但缺少 IEND、IEND 后附加字节三种案例；每个 PNG 样例都通过真实 CLI 检查并断言报告失败。
- 新增 1×1 PNG 样例使用有效 chunk CRC，便于单独验证 IEND 缺失与尾随数据边界；不把 IDAT 解压或像素正确性纳入当前承诺。
- 同步更新 README、项目简介和初审清单，列明新增回归覆盖。没有新增生产代码或真实用户试用记录。

Windows 本机 `moon fmt`、`moon info`、`moon check --target native --deny-warn`、`moon test --target native`（14 passed）及 `moon run --target native scripts/cli_smoke.mbtx` 均通过；格式检查通过，CLI smoke 连续运行两次均成功。提交 `31032ae` 的 [GitHub Actions 运行 #35216322259](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35216322259) 中 Ubuntu 和 Windows jobs 均通过。

## 2026-09-17：为素材报告增加 SHA-256 内容指纹

- 检查报告的 JSON 和 HTML 现在为受支持的素材输出 SHA-256，便于保存报告后核对交付文件是否变化；指纹用于内容比对，不是数字签名或来源认证。
- 以 64 KiB 块流式哈希，避免把整个图片读入内存。清单超出 `max_bytes` 时跳过哈希；哈希期间文件大小发生变化或读取失败时报告失败，不给出看似有效的指纹。
- 使用版本固定为 `moonbitlang/x@0.5.5` 的 `moonbitlang/x/crypto` SHA-256 实现；该仓库将自身标为实验性，项目只使用其哈希 API，并用空串、`abc` 分块向量和端到端已知文件哈希验证。
- 增加 70,000 字节回归样例，跨过 64 KiB 读取边界，并独立核对预期哈希；另验证超限素材显示未计算标记。
- 本轮由 Codex 辅助实现；示例仍为合成 fixture，没有外部用户试用或反馈。

本机 `moon update`、`moon fmt` / `moon fmt --check`、`.mbtx` 格式检查、`moon info`、`moon check --target native --deny-warn` 均通过；`moon test --target native` 为 15 passed；CLI smoke 连续运行两次均成功，覆盖 JSON/HTML 指纹、70,000 字节多块哈希、超限跳过及此前 PNG 结构边界。提交 `6db5ea7` 的 [GitHub Actions 运行 #35218263425](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35218263425) 中 Ubuntu 与 Windows jobs 均成功。

## 2026-09-17：在规格错误报告中展示期望值

- 修正尺寸和文件大小失败提示过于笼统的问题：JSON、HTML 与 CLI 输出现在会同时列出清单要求值和检测到的值，用户不必切回清单文件才能确定修正方向。
- CLI smoke 使用干净 PNG 构造一个宽高和大小上限均错误的清单，并断言两类报告都包含期望尺寸、实际尺寸及大小上限。
- 本轮由 Codex 辅助实现和测试；回归 fixture 仍是合成数据，没有真实用户试用记录。

Windows 本机 `moon fmt --check`、`.mbtx` 格式检查、`moon info`、`moon check --target native --deny-warn` 均通过；`moon test --target native` 为 15 passed；CLI smoke 连续两次通过（含 JSON、HTML、命令行错误规格说明断言）。提交 `c3d7911` 的 [GitHub Actions 运行 #35220136903](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35220136903) 中 Ubuntu 与 Windows jobs 均成功。

## 2026-09-17：让可运行失败演示覆盖规格诊断

- 将 `examples/demo` 中合成 `poster.png` 的清单改为故意错误的 5×9 与 1-byte 上限；运行报告现在会同时展示尺寸要求/实际值、体积上限、缺失文件和三项多余图片。
- 端到端 smoke 断言演示报告的失败计数、JSON/HTML 规格诊断和缺失/多余项；README 与初审清单同步说明这是合成失败夹具，避免被误认为真实用户素材。
- 本轮更新的是可复现演示，不代表已取得真实用户试用反馈。

Windows 本机 `moon fmt --check`、`.mbtx` 格式检查、`moon info`、`moon check --target native --deny-warn` 均通过；`moon test --target native` 为 15 passed；CLI smoke 连续两次通过；公开失败演示报告 5 项待处理并以预期退出码 1 结束。提交 `169fbc4` 的 [GitHub Actions 运行 #35221569664](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35221569664) 中 Ubuntu 与 Windows jobs 均成功。

## 2026-09-17：增加 WebP 尺寸与 RIFF 容器预检

- 新增 `.webp` 清单与目录扫描：读取有损 VP8、无损 VP8L 的图像尺寸，以及扩展 VP8X 的画布尺寸；对动画 WebP 的尺寸只报告画布，不解析动画帧。
- 校验 RIFF 声明文件长度、块边界、奇数长度块的零填充和必要的图像数据块；拒绝只有 VP8X 画布头、没有图像数据块的文件。不解码 VP8/VP8L 位流，也不等于完整 WebP 解码器。
- 格式字段按 [Google WebP 容器规范](https://developers.google.com/speed/webp/docs/riff_container)、[WebP Lossless Bitstream 规范](https://developers.google.com/speed/webp/docs/webp_lossless_bitstream_specification) 和 [RFC 6386 VP8 规范](https://datatracker.ietf.org/doc/html/rfc6386)实现。
- 增加 VP8、VP8L、VP8X 头单测；clean 示例新增三种编码形式的 WebP 夹具，demo 新增一项多余 WebP。夹具由 Pillow/libwebp 从仓库内合成 PNG/JPEG 导出，Pillow 解码校验和 CLI 全流程分别验证。
- 本轮由 Codex 辅助实现；新增图片均为合成夹具，未完成真实用户试用。

Windows 本机 `moon fmt --check`、`.mbtx` 格式检查、`moon info`、`moon check --target native --deny-warn` 均通过；`moon test --target native` 为 19 passed；CLI smoke 连续两次通过，含通过样例 WebP SHA-256、真实 WebP 清单检查、缺少图像数据的 VP8X 拒绝及非零 RIFF 填充拒绝。提交 `74cd3c5` 的 [GitHub Actions 运行 #35225659928](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35225659928) 中 Ubuntu 与 Windows jobs 均通过格式检查、无警告检查、原生测试及 CLI smoke。

## 2026-09-17：提示素材包中的相同内容指纹

- 复用点检时已生成的 SHA-256，对清单文件和额外图片做包内比对；发现相同指纹时在 JSON/HTML/CLI 详情中提示首个匹配路径，状态仍按原有规格判断，避免把有意复用误判成失败。
- 新增两份相同 WebP 的独立可运行样例，并让错误演示包含一对未登记的相同 WebP；分别覆盖清单内重复与额外图片匹配清单内容。
- SHA-256 相同表示指纹相同，不作来源认证，也不自动删除、改写或判定图片视觉内容相同。

Windows 本机 `moon fmt --check` 与 `moon fmt --check scripts/cli_smoke.mbtx`、`moon info`、`moon check --target native --deny-warn` 均通过；`moon test --target native` 为 20 passed，CLI smoke 通过，包含清单内重复图片保持通过及额外图片命中已登记内容。提交 `0659816` 的 [GitHub Actions 运行 #35228552433](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35228552433) 中 Ubuntu 与 Windows jobs 均通过格式检查、无警告检查、20 项原生测试及 CLI smoke。

## 2026-09-17：准备真实素材试用记录模板

- 新增空白试用流程，要求记录真实场景、规格来源、已知预期、命令与版本、耗时、人工核实、误报/漏报及反馈；允许脱敏后再公开。
- 明确受控的清单错误测试与合成 fixture 不能替代真实试用，也不能仅凭一次未发现问题就推断工具没有漏报。
- 真实素材试用已于 2026-09-26 完成，结论范围与材料清理说明见 2026-09-26 开发记录。
- 提交 `2ff0fe1` 的 [GitHub Actions 运行 #35230002092](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35230002092) 中 Ubuntu 和 Windows jobs 均通过格式检查、无警告检查、20 项原生测试及 CLI smoke。
