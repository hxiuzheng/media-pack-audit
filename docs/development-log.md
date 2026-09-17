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
