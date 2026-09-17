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
        about="Directory tree containing the delivered PNG/JPEG/WebP/GIF images",
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
  let manifest_json = @json.parse(manifest_text) catch {
    error => raise Failure::Failure("清单格式错误：\{error}")
  }
  match first_manifest_field_error(manifest_json) {
    Some(error) => raise Failure::Failure("清单格式错误：\{error}")
    None => ()
  }
  let manifest : @audit.Manifest = @json.from_json(manifest_json) catch {
    error => raise Failure::Failure("清单格式错误：\{error}")
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

  println(
    "片盒点检完成：\{report.checked} 项，\{report.passed} 项通过，\{report.failed} 项需处理。",
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
fn join_path(root : String, name : String) -> String {
  if root.has_suffix("/") || root.has_suffix("\\") {
    root + name
  } else if root.contains("\\") {
    root + "\\" + name
  } else {
    root + "/" + name
  }
}

///|
/// Reject misspelled keys and fractional dimensions or byte limits instead
/// of silently ignoring or truncating a handoff requirement.
fn first_manifest_field_error(json : Json) -> String? {
  match json {
    Object(root) =>
      for key, value in root {
        if key != "assets" {
          return Some("未知字段 \{key}")
        }
        match value {
          Array(assets) =>
            for index in 0..<assets.length() {
              match assets[index] {
                Object(fields) =>
                  for field, field_value in fields {
                    if field != "file" &&
                      field != "label" &&
                      field != "width" &&
                      field != "height" &&
                      field != "max_bytes" {
                      return Some("未知字段 assets[\{index}].\{field}")
                    }
                    if field == "width" ||
                      field == "height" ||
                      field == "max_bytes" {
                      match field_value {
                        Number(number, ..) if number.floor() != number =>
                          return Some(
                            "assets[\{index}].\{field} 必须是整数",
                          )
                        _ => ()
                      }
                    }
                  }
                _ => ()
              }
            }
          _ => ()
        }
      }
    _ => ()
  }
  None
}
