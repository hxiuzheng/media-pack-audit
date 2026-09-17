# 开发记录

记录实际完成的改动和验证结果，不追记或拆分此前没有发生的工作。

## 2026-09-17：在报告中固定所用规格清单

- JSON、HTML 报告和 CLI 摘要现在显示清单原始字节的 SHA-256；归档报告可以用该指纹对应回当时使用的规格文件，空格或换行变化也会产生不同指纹。
- 增加 SHA-256 标准向量单测，并在端到端 smoke 中用独立计算的 `examples/clean/media-pack.json` 指纹，核对 JSON、HTML 和 CLI 三处输出完全一致。
- 同步 README、项目简介和初审测试清单；明确指纹只是内容标识，不是来源认证或数字签名。
- 本机 Windows 验证：`moon fmt --check`、`.mbtx` 格式检查、`moon info`、`moon check --target native --deny-warn`、`moon test --target native`（20 passed）和 CLI smoke 全部通过。C 运行时依赖仍输出 `EINVAL` 宏重定义 warning；MoonBit 检查无警告且命令成功。
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
- 目前仍无外部用户或真实素材试用记录；模板是待办工具，不是试用结果。
- 提交 `2ff0fe1` 的 [GitHub Actions 运行 #35230002092](https://github.com/hxiuzheng/media-pack-audit/actions/runs/35230002092) 中 Ubuntu 和 Windows jobs 均通过格式检查、无警告检查、20 项原生测试及 CLI smoke。
