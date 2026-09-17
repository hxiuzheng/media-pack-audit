///|
pub(all) struct AssetSpec {
  file : String
  width : Int
  height : Int
  max_bytes : Int
} derive(FromJson, ToJson)

///|
pub(all) struct Manifest {
  assets : Array[AssetSpec]
} derive(FromJson, ToJson)

///|
pub(all) struct CheckResult {
  file : String
  status : String
  observed : String
  details : String
} derive(ToJson)

///|
pub(all) struct AuditReport {
  asset_dir : String
  checked : Int
  passed : Int
  failed : Int
  results : Array[CheckResult]
} derive(ToJson)

///|
pub fn png_dimensions(bytes : Bytes) -> (Int, Int)? {
  if bytes.length() < 33 {
    return None
  }
  if !bytes.has_prefix(b"\x89PNG\r\n\x1A\n") {
    return None
  }
  if bytes[8] != b'\x00' ||
    bytes[9] != b'\x00' ||
    bytes[10] != b'\x00' ||
    bytes[11] != b'\x0D' {
    return None
  }
  if bytes[12] != b'I' ||
    bytes[13] != b'H' ||
    bytes[14] != b'D' ||
    bytes[15] != b'R' {
    return None
  }

  let width = read_png_dimension(bytes, 16)
  let height = read_png_dimension(bytes, 20)
  match (width, height) {
    (Some(w), Some(h)) if w > 0 && h > 0 => Some((w, h))
    _ => None
  }
}

///|
fn read_png_dimension(bytes : Bytes, offset : Int) -> Int? {
  let first = bytes[offset].to_int()
  if first >= 128 {
    return None
  }
  Some(
    first * 16777216 +
    bytes[offset + 1].to_int() * 65536 +
    bytes[offset + 2].to_int() * 256 +
    bytes[offset + 3].to_int(),
  )
}

///|
async fn read_png_dimensions(path : String, size : Int64) -> (Int, Int)? {
  if size < Int::to_int64(33) {
    return None
  }
  let file = @fs.open(path, mode=@fs.ReadOnly)
  defer file.close()
  let header = file.read_exactly(33)
  png_dimensions(header)
}

///|
pub async fn scan_assets(
  asset_dir : String,
  manifest : Manifest,
) -> AuditReport {
  let results : Array[CheckResult] = []
  let seen_files : Array[String] = []

  if manifest.assets.is_empty() {
    results.push({
      file: "<manifest>",
      status: "FAIL",
      observed: "0 项",
      details: "清单至少需要一项素材",
    })
  }

  let entries = @fs.readdir(asset_dir, sort=true)
  for spec in manifest.assets {
    let mut duplicate = false
    for previous in seen_files {
      if previous == spec.file {
        duplicate = true
      }
    }
    seen_files.push(spec.file)

    if !is_safe_filename(spec.file) {
      results.push({
        file: spec.file,
        status: "FAIL",
        observed: "—",
        details: "清单中的 file 必须是单层文件名，不能包含路径",
      })
      continue
    }
    if duplicate {
      results.push({
        file: spec.file,
        status: "FAIL",
        observed: "重复项",
        details: "清单中出现了重复文件名",
      })
      continue
    }
    if spec.width <= 0 || spec.height <= 0 || spec.max_bytes <= 0 {
      results.push({
        file: spec.file,
        status: "FAIL",
        observed: "—",
        details: "宽、高和 max_bytes 必须为正数",
      })
      continue
    }
    if !spec.file.has_suffix(".png") {
      results.push({
        file: spec.file,
        status: "FAIL",
        observed: "不支持的格式",
        details: "当前版本只检查 PNG 图片",
      })
      continue
    }

    let path = join_path(asset_dir, spec.file)
    if !contains_entry(entries, spec.file) || !@fs.exists(path) {
      results.push({
        file: spec.file,
        status: "FAIL",
        observed: "缺失",
        details: "清单要求的文件名（含大小写）没有交付",
      })
      continue
    }
    let kind = @fs.kind(path, follow_symlink=false)
    if kind != @fs.FileKind::Regular {
      results.push({
        file: spec.file,
        status: "FAIL",
        observed: "非普通文件",
        details: "清单路径必须指向普通文件",
      })
      continue
    }

    let size = @fs.file_size(path)
    let issues : Array[String] = []
    if size > Int::to_int64(spec.max_bytes) {
      issues.push("文件大小超过 max_bytes")
    }
    let dimensions = read_png_dimensions(path, size)
    let observed = match dimensions {
      Some((width, height)) => "\{width} × \{height}，\{size} bytes"
      None => {
        issues.push("PNG 文件头无效或不完整")
        "\{size} bytes"
      }
    }
    match dimensions {
      Some((width, height)) if width != spec.width || height != spec.height =>
        issues.push("实际尺寸与清单不一致")
      _ => ()
    }
    let status = if issues.is_empty() { "PASS" } else { "FAIL" }
    let details = if issues.is_empty() {
      "符合清单规格"
    } else {
      issues.join("；")
    }
    results.push({ file: spec.file, status, observed, details, })
  }

  for name in entries {
    if name.has_suffix(".png") {
      let mut expected = false
      for spec in manifest.assets {
        if spec.file == name {
          expected = true
        }
      }
      if !expected {
        let path = join_path(asset_dir, name)
        if @fs.kind(path, follow_symlink=false) == @fs.FileKind::Regular {
          let size = @fs.file_size(path)
          results.push({
            file: name,
            status: "EXTRA",
            observed: "\{size} bytes",
            details: "PNG 文件未列在素材清单中",
          })
        }
      }
    }
  }

  let mut passed = 0
  let mut failed = 0
  for result in results {
    if result.status == "PASS" {
      passed += 1
    } else {
      failed += 1
    }
  }
  { asset_dir, checked: results.length(), passed, failed, results, }
}

///|
fn contains_entry(entries : Array[String], expected : String) -> Bool {
  for entry in entries {
    if entry == expected {
      return true
    }
  }
  false
}

///|
fn is_safe_filename(name : String) -> Bool {
  if name == "" || name == "." || name == ".." {
    return false
  }
  for character in name {
    if character == '/' || character == '\\' {
      return false
    }
  }
  true
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
