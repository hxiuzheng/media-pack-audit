// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "hxiuzheng/media-pack-audit"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/hxiuzheng/media-pack-audit"

license = "Apache-2.0"

keywords = [ "moonbit", "digital-media", "asset-validation", "cli" ]

preferred_target = "native"

description = "A MoonBit CLI that checks visual asset handoff folders against a media manifest."

import {
  "moonbitlang/async@0.22.1",
  "moonbitlang/x@0.5.5",
}
