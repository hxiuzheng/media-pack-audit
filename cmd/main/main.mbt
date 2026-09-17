///|
/// Entry point for the CLI or runnable program in this template.
/// Keep main focused; move logic into the library package.
/// Run with `moon run cmd/main` from the project root.
async fn main {
  let command = @argparse.Command(
    "media-pack-audit",
    about="Check a visual asset handoff against a JSON manifest.",
    positionals=[
      @argparse.PositionArg(
        "manifest",
        about="Path to media-pack.json",
        num_args=@argparse.ValueRange::single(),
      ),
      @argparse.PositionArg(
        "assets",
        about="Directory containing the delivered PNG files",
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
  let matches = command.parse()
  let manifest_path = matches.values["manifest"][0]
  let assets_dir = matches.values["assets"][0]
  let output_dir = matches.values["output"][0]

  if !@fs.exists(manifest_path) {
    raise Failure::Failure("找不到素材清单：\{manifest_path}")
  }
  if !@fs.exists(assets_dir) {
    raise Failure::Failure("找不到素材目录：\{assets_dir}")
  }

  let manifest_text = @fs.read_file(manifest_path).text()
  let manifest : @audit.Manifest = @json.from_json(@json.parse(manifest_text)) catch {
    error => raise Failure::Failure("清单格式错误：\{error}")
  }

  let report = @audit.scan_assets(assets_dir, manifest)
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

  println(
    "片盒点检完成：\{report.checked} 项，\{report.passed} 项通过，\{report.failed} 项需处理。",
  )
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
fn join_path(root : String, name : String) -> String {
  if root.has_suffix("/") || root.has_suffix("\\") {
    root + name
  } else if root.contains("\\") {
    root + "\\" + name
  } else {
    root + "/" + name
  }
}
