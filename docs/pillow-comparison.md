# 片盒点检与 Pillow：功能边界对照

这份对照说明产品职责和 Pillow 的相邻能力。它本身不把清单、比较或报告当作扣除通用工作的净核心证明；本次申报对应的自有实现范围、明确扣除项和可运行反例见[本次范围与可验收核心事实](core-scope.md)。产品面向交付目录预检，AVIF 的有界关系检查是其中独立调用的语义适配器；Pillow 面向图像打开、解码、变换和编码，两者在图像格式/尺寸读取上有重叠。

## 按验收对象比较

| 维度 | 片盒点检（本仓库） | Pillow | 关系与边界 |
|---|---|---|---|
| 主要对象 | 清单描述的一组普通文件和图片，以及它们所在的交付目录；本次申报的技术子范围是直接静态 AVIF 主图元数据关系 | 一张或一组可由相应插件打开的图像 | 一个面向整包交付预检并实现受限 AVIF 关系诊断，一个面向图像编解码和处理；图像元数据领域有重叠 |
| 输入 | JSON 清单 + 根目录；规则由交付要求提供 | 图片文件/字节流 + 图像操作参数 | Pillow 不会自动知道这批交付应有哪些文件或规格；调用者可以自行编写外围清单流程 |
| 图片读取 | 对支持格式读取所需的内容格式、尺寸等元数据；PNG/WebP 有限容器检查；AVIF 有界结构关系检查 | 提供多格式图像打开/解码；具体格式能力取决于 Pillow 的插件及构建能力 | 尺寸和格式信息是明确的重叠区；本项目的受限解析结果不等于像素解码或完整格式合规验证 |
| 图片变换 | 不改写图片，不裁剪、缩放、旋转或滤镜处理 | 提供像素级操作、变换、格式转换及保存 | 这是 Pillow 的能力范围，不是本项目范围 |
| 交付规则 | 可检查文件存在性、安全相对路径、格式、宽高、宽高比、单文件大小上下限、SHA-256、整包总容量、未登记文件和重复内容提示 | 可以通过 Python 程序组合图像信息，但上述整包清单验收不是 Pillow 的图像 API | 这是产品集成能力；本次申报的独立语义实现按核心范围说明核验，不用清单和报告抵扣后的剩余部分替它背书 |
| 结果 | MoonBit API 结果，以及 HTML/JSON 汇总和逐项诊断；扫描只读输入 | 图像对象及图像处理结果，调用者决定如何记录或汇总 | 项目报告保存的是规格验收结果，不是图像编辑结果 |
| AVIF 范围 | 直接静态主图的有界元数据一致性子集；检查主图声明、属性关联和显式数据区间，读取上限及未支持项见 [README](../README.md#avif-有界结构一致性验证) | 官方格式文档列出 AVIF 打开/保存及 AVIF sequence 支持；解码能力受其 AVIF 后端和构建环境影响 | 这是不同的 AVIF 目标：本项目的关系诊断不是完整解码器；Pillow 的解码/保存说明也不等于清单驱动的整包验收 |
| 实现与依赖 | MoonBit；AVIF 核心由本仓库实现；CRC-32 和 SHA-256 复用已声明依赖 | Python Imaging Library 的图像处理 API 及其格式插件/构建依赖 | 本仓库不依赖 Pillow、libavif 或 Pillow 代码来执行验收 |

## 用哪个工具

- 要打开图片、解码像素、裁剪/缩放/旋转、转换格式或保存变换结果：选择 Pillow 等图像处理工具。
- 要按交付方给定的清单检查整包是否缺件、是否夹带未登记文件、图片规格和文件预算是否符合：选择片盒点检。
- 既要生成或处理图片又要验收交付包：用图像工具生成素材，再用片盒点检按清单验收。图像生成成功本身不代表交付包符合清单。

## 仓库内可复现的验收路径

下面的两个样例使用同一个产品入口。通过包检查展示符合清单的目录；受控错误包展示缺件、尺寸/大小问题和未登记文件。Pillow 的单图打开不会替代这些包级断言；反过来，片盒点检的报告也不证明图像像素可以成功解码。

```sh
# 符合清单的整包：预期退出码 0，生成 HTML 与 JSON 报告。
moon run --target native cmd/main -- examples/clean/media-pack.json examples/clean/assets --output _build/pillow-comparison/clean

# 受控错误整包：预期退出码 1，报告定位清单错误、缺件或未登记文件。
moon run --target native cmd/main -- examples/demo/media-pack.json examples/demo/assets --output _build/pillow-comparison/issues

# 运行版本库中的图片结构、清单与报告回归。
moon test --target native --deny-warn
```

命令结果只验证仓库中所列代码与夹具。它不代表真实用户试用、外部采用、Pillow 兼容性认证或评审通过。若要单独检查本次申报所对应的 AVIF 语义范围，可运行：

```sh
moon run --target native examples/avif_semantics
```

该命令直接调用公开结构 API，不加载外部规格清单或报告流程；其边界、属性语义和每个破坏单一约束的预期结果见[核心范围说明](core-scope.md)。

## 事实来源

- [Pillow 教程](https://pillow.readthedocs.io/en/stable/handbook/tutorial.html)：图像打开、保存、裁剪、旋转、变换和缩放等 API。
- [Pillow 图像文件格式](https://pillow.readthedocs.io/en/stable/handbook/image-file-formats.html)：各格式的读写能力和格式特定限制；格式支持可能依赖可用插件或构建组件。
- [Pillow 当前 AVIF 文档源码](https://github.com/python-pillow/Pillow/blob/main/docs/handbook/image-file-formats.rst#avif)与[构建依赖说明](https://github.com/python-pillow/Pillow/blob/main/docs/installation/building-from-source.rst)：记录其 AVIF 解码/编码和序列支持，以及 AVIF 后端依赖；这是功能比较依据，不是本项目运行依赖。
- [Pillow Image API](https://pillow.readthedocs.io/en/stable/reference/Image.html)：`Image.open()` 与图像对象接口。
- [本仓库 README](../README.md)：当前公开功能、AVIF 支持子集、依赖和可复现示例。

本说明依据以上公开文档描述产品功能，不声称比较了未经验证的性能、解码覆盖率或完整格式合规性。Pillow 是独立项目，本仓库未复制其代码，也未把它列为运行依赖。
