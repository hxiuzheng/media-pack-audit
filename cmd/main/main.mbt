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
  match first_duplicate_json_key(manifest_text) {
    Some(key) =>
      raise Failure::Failure("清单格式错误：重复 JSON 字段 \{key}")
    None => ()
  }
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

///|
/// JSON objects normally decode into maps, which erase repeated member names.
/// Scan the original text first so ambiguous requirements cannot pass silently.
fn first_duplicate_json_key(text : String) -> String? {
  let input = text[:]
  let object_keys : Array[Map[String, Bool]] = []
  let mut in_string = false
  let mut escaped = false
  let mut quote_start = 0
  for index in 0..<input.length() {
    let code = input.unsafe_get(index)
    if in_string {
      if escaped {
        escaped = false
      } else if code == 92 {
        escaped = true
      } else if code == 34 {
        in_string = false
        let mut colon = index + 1
        while colon < input.length() {
          let whitespace = input.unsafe_get(colon)
          if whitespace == 32 ||
            whitespace == 9 ||
            whitespace == 10 ||
            whitespace == 13 {
            colon += 1
          } else {
            break
          }
        }
        if colon < input.length() &&
          input.unsafe_get(colon) == 58 &&
          object_keys.length() > 0 {
          let key_literal = input
            .view(start_offset=quote_start, end_offset=index + 1)
            .to_owned()
          let parsed_key = @json.parse(key_literal) catch { _ => Json::null() }
          match parsed_key {
            String(key) => {
              let last = object_keys.length() - 1
              let keys = object_keys[last]
              if keys.contains(key) {
                return Some(key)
              }
              keys.set(key, true)
              object_keys[last] = keys
            }
            _ => ()
          }
        }
      }
    } else if code == 34 {
      in_string = true
      escaped = false
      quote_start = index
    } else if code == 123 {
      object_keys.push(Map([]))
    } else if code == 125 {
      ignore(object_keys.pop())
    }
  }
  None
}

///|
/// Reject misspelled keys and fractional dimensions or byte limits instead
/// of silently ignoring or truncating a handoff requirement.
fn first_manifest_field_error(json : Json) -> String? {
  match json {
    Object(root) =>
      for key, value in root {
        if key != "assets" && key != "max_total_bytes" {
          return Some("未知字段 \{key}")
        }
        if key == "max_total_bytes" {
          match value {
            Number(number, ..) if number.floor() != number =>
              return Some("max_total_bytes 必须是整数")
            Number(number, ..) if number <= 0 =>
              return Some("max_total_bytes 必须为正整数")
            _ => ()
          }
        } else {
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
                        field != "max_bytes" &&
                        field != "expected_sha256" &&
                        field != "aspect" {
                        return Some("未知字段 assets[\{index}].\{field}")
                      }
                      if field == "expected_sha256" {
                        match field_value {
                          String(expected) => {
                            if expected.length() != 64 {
                              return Some(
                                "assets[\{index}].expected_sha256 必须是 64 位十六进制字符串",
                              )
                            }
                            for character in expected {
                              if !is_hex_character(character) {
                                return Some(
                                  "assets[\{index}].expected_sha256 必须是 64 位十六进制字符串",
                                )
                              }
                            }
                          }
                          _ => ()
                        }
                      }
                      if field == "aspect" {
                        match field_value {
                          String(aspect) =>
                            if @audit.parse_aspect(aspect) is None {
                              return Some(
                                "assets[\{index}].aspect 必须是 W:H 形式的正整数比例",
                              )
                            }
                          _ => ()
                        }
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
      }
    _ => ()
  }
  None
}

///|
fn is_hex_character(character : Char) -> Bool {
  (character >= '0' && character <= '9') ||
  (character >= 'a' && character <= 'f') ||
  (character >= 'A' && character <= 'F')
}
