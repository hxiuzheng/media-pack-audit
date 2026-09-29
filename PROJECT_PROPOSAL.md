# 项目申报简介｜片盒点检 MediaPack Audit

- **项目方向：** 可复用库 · 数字媒体素材交付预检
- **项目仓库：** <https://github.com/hxiuzheng/media-pack-audit>
- **许可证：** Apache-2.0

## 项目解决什么问题

数字媒体课程与小型内容制作经常要交付海报、封面和社媒图片。只靠人工核对文件名、像素尺寸和体积，容易漏掉缺图、规格错误或多交文件。片盒点检面向数字媒体学生与小型制作团队，把交付要求写成清单，在交付前重复检查并留下可分享的报告。

## 当前方案与可验证范围

用户提供一份 JSON 素材清单和素材目录，由 MoonBit 可复用库递归检查；CLI 和独立 MoonBit 包是库的消费端。校验范围包括普通文件、PNG 各块边界与 CRC、JPEG SOF/EXIF Orientation、WebP RIFF 容器、GIF/BMP/TIFF/SVG/AVIF/JP2/ICO/PSD 尺寸头、清单字段、相对路径、容量与重复路径。素材项可选填用途标签、aspect、min_bytes、format 和 expected_sha256；报告包含要求值、实际值及 HTML/JSON 结果。指纹用于内容比对，不提供来源认证；超限文件跳过哈希；相同指纹只提示潜在重复，由人工确认。工具不解码像素，尺寸头解析不等于完整格式验证。

项目目前支持目录树中的 PNG、JPEG、WebP、GIF、BMP、TIFF、SVG、AVIF、JP2、ICO 和 PSD。PNG 校验每个块的 CRC 及必需的 IHDR/IDAT/IEND 基本结构，但不校验所有块类型各自的语义与排序规则，也不解压图像数据；JPEG 元数据最多扫描文件开头 4 MiB，缺少有效 EXIF Orientation 时沿用 SOF 存储尺寸；WebP 检查 RIFF 块边界、填充和首个图像/画布尺寸头，但不解码 VP8/VP8L 位流，也不核验动画帧语义；GIF 只核对画布尺寸，不检查帧或播放时序；BMP 读取 DIB 头的宽高，不解码像素；TIFF 读取 ImageWidth/ImageLength 标签，不解码像素；SVG 只读 width/height 属性或 viewBox 的整数宽高，不解析 CSS 继承或渲染；AVIF 沿 meta→iprp→ipco→ispe 盒链读取尺寸，不解码 AV1 位流；JPEG 2000 读取 jp2h/ihdr 盒，不解码码流；ICO/CUR 读取首项目录项尺寸；PSD 读取头部宽高。它不解码像素、不判断视觉内容或色彩空间，也不修改素材；这些边界会在报告与 README 中说明。

## 技术实现与赛事匹配

核心解析、清单扫描和报告生成以 MoonBit 实现，CLI 负责参数、清单文件读取和报告落盘。根包公开格式尺寸读取、内容格式识别、严格的 `parse_manifest_json`、`scan_assets`、`scaffold_manifest` 和报告 API；CLI 导入根包，另有 `examples/library_consumer` 作为独立包直接导入并调用库接口、实际落盘 HTML/JSON 报告。CI 对该消费示例执行运行验证。初审要求的 Pillow/生态复用回应及边界见下方和 README。

Pillow 的 `Image.open()`/`Image.size` 是成熟的按格式读取图像尺寸入口，本项目参考了它的使用目标，并使用 Pillow 生成部分合成回归样本；Pillow 是 Python 图像库，像素加载/处理范围超出 MoonBit 头部预检库的依赖边界，故不作为依赖，也不声称移植其代码。调研的 MoonBit 图像库主要提供解码、图像表示或处理，不能直接替代本项目“只读取尺寸头并执行清单验收”的完整流程。对可复用算法则直接依赖 `gmlewis/crc32` 做 CRC-32、`moonbitlang/x/crypto` 做 SHA-256，不自行实现这两类成熟算法。格式头解析和素材包规则保留为本库的 MoonBit 适配层。生态对照链接见 README「生态调研与复用取舍」。

## 当前验证证据与边界

当前主分支已提供 PNG、JPEG、WebP、GIF、BMP、TIFF、SVG、AVIF、JP2、ICO 和 PSD 的尺寸预检，以及清单字段校验、路径安全、单项/总容量限制、SHA-256 指纹、宽高比校验、重复内容提示和 HTML/JSON 报告。仓库同时提供通过、格式错误、规格不符、缺失、多余文件和重复内容样例。

项目的自动化证据由当前提交对应的 MoonBit 格式检查、无警告检查、单元测试、独立库消费端、CLI 端到端回归和 Ubuntu/Windows CI 记录支持；历史提交结果不替代当前提交结果。另有一次由项目负责人在 Windows 上执行的真实 JPEG 文件试用；该试用验证了真实文件读取和受控规格错误，但规格来自文件实际属性，样本小且没有独立用户反馈，不能表述为行业效果验证。

当前限制也明确写入 README：工具不解码像素，不判断视觉内容、色彩空间、动画时序或完整格式语义；它是交付规格预检器，不是完整图像解码器或视觉质量审核系统。

## 人工主导、AI 辅助与复核要求

项目范围、验收标准、只读与路径安全边界、格式支持取舍、公开声明和最终提交均由我本人负责。AI 仅作为 API 查询、重复性代码草拟、边界用例枚举、编译诊断和文档整理助手。每项 AI 建议都必须由我亲自检查源码、运行相关测试并理解限制；未完成复核的改动不作为最终成果。仓库保留真实的 AI 辅助披露，不改写提交历史来伪造纯人工作者。提交前人工复核项目见 [`docs/human-review-checklist.md`](docs/human-review-checklist.md)。

## 选题区分

片盒点检只做“验收”，不做“生成”。MoonBit 生态里有两个相邻但方向不同的项目：`moonbit-posterkit` 是数据驱动的海报和封面生成 DSL，用模板和布局把数据渲染成 SVG 海报、封面和社媒卡片；MoonBitMark 把文档和图片转换成 Markdown。它们的共同点是“生产或转换图片”，而片盒点检做的是“核对已经交付的图片”——不解码像素、不改动输入文件、不产出任何图片，只对照清单检查交付素材是否缺图、尺寸不对、超限或有未登记文件。三者是互补而不是替代：可以用 posterkit 生成海报、用 MoonBitMark 做文档配图，再在最终交付前用片盒点检对整包素材做一次可重复、可留档的验收。
