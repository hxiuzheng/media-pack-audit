///|
/// Entry point for the media-pack-audit CLI. The root command dispatches to
/// two subcommands: `check` (the default) audits a manifest against a directory,
/// and `init` scaffolds a starter manifest from an existing directory.
async fn main {
  let check = @argparse.Command(
    "check",
    about="Check a visual asset handoff against a JSON manifest.",
    positionals=[
      @argparse.PositionArg(
        "manifest",
        about="Path to media-pack.json",
        num_args=@argparse.ValueRange::single(),
      ),
      @argparse.PositionArg(
        "assets",
        about="Directory tree containing the delivered images",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    options=[
      @argparse.OptionArg(
        "output",
        short='o',
        about="Directory for the HTML and JSON reports",
        default_values=["report"],
      ),
    ],
  )
  let init = @argparse.Command(
    "init",
    about="Generate a starter media-pack.json from an existing asset directory.",
    positionals=[
      @argparse.PositionArg(
        "assets",
        about="Directory tree containing the delivered images",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    options=[
      @argparse.OptionArg(
        "output",
        short='o',
        about="Path to write the generated manifest",
        default_values=["media-pack.json"],
      ),
    ],
  )
  let command = @argparse.Command(
    "media-pack-audit",
    about="Check a visual asset handoff against a JSON manifest.",
    subcommands=[check, init],
    default_subcommand="check",
  )
  let matches = command.parse()
  match matches.subcommand {
    Some(("init", sub)) => run_init(sub)
    Some((_, sub)) => run_check(sub)
    None => run_check(matches)
  }
}

///|
async fn run_check(matches : @argparse.Matches) -> Unit {
  let manifest_path = matches.values["manifest"][0]
  let assets_dir = matches.values["assets"][0]
  let output_dir = matches.values["output"][0]

  if !@fs.exists(manifest_path) {
    raise Failure::Failure("找不到素材清单：\{manifest_path}")
  }
  if @fs.kind(manifest_path) != @fs.FileKind::Regular {
    raise Failure::Failure(
      "素材清单路径必须是普通文件：\{manifest_path}",
    )
  }
  if !@fs.exists(assets_dir) {
    raise Failure::Failure("找不到素材目录：\{assets_dir}")
  }
  if @fs.kind(assets_dir) != @fs.FileKind::Directory {
    raise Failure::Failure("素材目录路径必须是目录：\{assets_dir}")
  }

  let manifest_data = @fs.read_file(manifest_path)
  let manifest_text = manifest_data.text()
  let manifest_sha256 = @audit.sha256_bytes(manifest_data.binary())
  let manifest = @audit.parse_manifest_json(manifest_text) catch {
    @audit.ManifestParseError::DuplicateJsonKey(key) =>
      raise Failure::Failure("清单格式错误：重复 JSON 字段 \{key}")
    @audit.ManifestParseError::InvalidField(message) =>
      raise Failure::Failure("清单格式错误：\{message}")
    @audit.ManifestParseError::InvalidJson(message) =>
      raise Failure::Failure("清单格式错误：\{message}")
  }

  let report = @audit.scan_assets(assets_dir, manifest, manifest_sha256)
  if @fs.exists(output_dir) {
    if @fs.kind(output_dir, follow_symlink=false) != @fs.FileKind::Directory {
      raise Failure::Failure(
        "输出路径已存在但不是普通目录：\{output_dir}",
      )
    }
  } else {
    @fs.mkdir(output_dir, recursive=true)
  }
  let json_path = join_path(output_dir, "report.json")
  let html_path = join_path(output_dir, "report.html")
  let json_text = @json.to_json(report).stringify(indent=2)
  @fs.write_file(json_path, json_text)
  @fs.write_file(html_path, @audit.render_html(report))

  let pass_rate = if report.checked == 0 {
    100
  } else {
    report.passed * 100 / report.checked
  }
  println(
    "片盒点检完成：\{report.checked} 项，\{report.passed} 项通过，\{report.failed} 项需处理，通过率 \{pass_rate}%。",
  )
  println("规格清单 SHA-256：\{report.manifest_sha256}")
  for result in report.results {
    println("[\{result.status}] \{result.file} — \{result.details}")
  }
  println("HTML 报告：\{html_path}")
  println("JSON 报告：\{json_path}")
  if report.failed > 0 {
    raise Failure::Failure(
      "检查未通过；请根据报告修正素材后重新运行。",
    )
  }
}

///|
async fn run_init(matches : @argparse.Matches) -> Unit {
  let assets_dir = matches.values["assets"][0]
  let output_path = matches.values["output"][0]

  if !@fs.exists(assets_dir) {
    raise Failure::Failure("找不到素材目录：\{assets_dir}")
  }
  if @fs.kind(assets_dir) != @fs.FileKind::Directory {
    raise Failure::Failure("素材目录路径必须是目录：\{assets_dir}")
  }
  if @fs.exists(output_path) {
    raise Failure::Failure(
      "输出路径已存在：\{output_path}；请删除或用 --output 指定新路径，避免覆盖已有清单",
    )
  }

  let result = @audit.scaffold_manifest(assets_dir)
  @fs.write_file(output_path, result.manifest)
  println("已生成清单：\{output_path}（\{result.generated} 项素材）")
  for skipped in result.skipped {
    println("跳过（无法读取尺寸）：\{skipped}")
  }
  println(
    "请按交付要求核对并补充 label、max_bytes 等字段后再运行 check。",
  )
}

///|
fn join_path(root : String, name : String) -> String {
  if root.has_suffix("/") || root.has_suffix("\\") {
    root + name
  } else if root.contains("\\") {
    root + "\\" + name
  } else {
    root + "/" + name
  }
}
