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
  if !png_ihdr_crc_is_valid(bytes) {
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
/// Validate the CRC for the first PNG chunk (IHDR), without decoding image data.
fn png_ihdr_crc_is_valid(bytes : Bytes) -> Bool {
  let crc = png_crc32(bytes, 12, 29)
  bytes[29].to_int() == ((crc >> 24) & 0xFF) &&
  bytes[30].to_int() == ((crc >> 16) & 0xFF) &&
  bytes[31].to_int() == ((crc >> 8) & 0xFF) &&
  bytes[32].to_int() == (crc & 0xFF)
}

///|
/// CRC-32/ISO-HDLC as used by PNG chunks.
fn png_crc32(bytes : Bytes, start : Int, end : Int) -> Int {
  let mut crc = -1
  for index in start..<end {
    crc = crc ^ bytes[index].to_int()
    for _ in 0..<8 {
      if (crc & 1) == 1 {
        crc = ((crc >> 1) & 0x7FFFFFFF) ^ 0xEDB88320
      } else {
        crc = (crc >> 1) & 0x7FFFFFFF
      }
    }
  }
  crc ^ -1
}

///|
pub fn jpeg_dimensions(bytes : Bytes) -> (Int, Int)? {
  if bytes.length() < 4 || bytes[0] != b'\xFF' || bytes[1] != b'\xD8' {
    return None
  }

  let mut offset = 2
  while offset < bytes.length() {
    if bytes[offset] != b'\xFF' {
      return None
    }
    offset += 1
    while offset < bytes.length() && bytes[offset] == b'\xFF' {
      offset += 1
    }
    if offset >= bytes.length() {
      return None
    }
    let marker = bytes[offset]
    offset += 1

    if marker == b'\x00' ||
      marker == b'\xD8' ||
      marker == b'\xD9' ||
      marker == b'\xDA' {
      return None
    }
    if is_standalone_jpeg_marker(marker) {
      continue
    }
    if offset + 2 > bytes.length() {
      return None
    }

    let segment_length = read_big_endian_u16(bytes, offset)
    if segment_length < 2 || offset + segment_length > bytes.length() {
      return None
    }
    if is_jpeg_start_of_frame(marker) {
      if segment_length < 8 {
        return None
      }
      let height = read_big_endian_u16(bytes, offset + 3)
      let width = read_big_endian_u16(bytes, offset + 5)
      let component_count = bytes[offset + 7].to_int()
      if component_count == 0 || segment_length != 8 + component_count * 3 {
        return None
      }
      if width > 0 && height > 0 {
        return Some((width, height))
      }
      return None
    }
    offset += segment_length
  }
  None
}

///|
/// Return the GIF87a/GIF89a logical screen dimensions without decoding image data.
pub fn gif_dimensions(bytes : Bytes) -> (Int, Int)? {
  if bytes.length() < 13 {
    return None
  }
  if !bytes.has_prefix(b"GIF87a") && !bytes.has_prefix(b"GIF89a") {
    return None
  }
  let width = read_little_endian_u16(bytes, 6)
  let height = read_little_endian_u16(bytes, 8)
  if width > 0 && height > 0 {
    Some((width, height))
  } else {
    None
  }
}

///|
fn read_big_endian_u16(bytes : Bytes, offset : Int) -> Int {
  bytes[offset].to_int() * 256 + bytes[offset + 1].to_int()
}

///|
fn read_little_endian_u16(bytes : Bytes, offset : Int) -> Int {
  bytes[offset].to_int() + bytes[offset + 1].to_int() * 256
}

///|
fn is_standalone_jpeg_marker(marker : Byte) -> Bool {
  match marker {
    b'\x01'
    | b'\xD0'
    | b'\xD1'
    | b'\xD2'
    | b'\xD3'
    | b'\xD4'
    | b'\xD5'
    | b'\xD6'
    | b'\xD7' => true
    _ => false
  }
}

///|
fn is_jpeg_start_of_frame(marker : Byte) -> Bool {
  match marker {
    b'\xC0'
    | b'\xC1'
    | b'\xC2'
    | b'\xC3'
    | b'\xC5'
    | b'\xC6'
    | b'\xC7'
    | b'\xC9'
    | b'\xCA'
    | b'\xCB'
    | b'\xCD'
    | b'\xCE'
    | b'\xCF' => true
    _ => false
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
async fn read_jpeg_dimensions(path : String, size : Int64) -> (Int, Int)? {
  if size < 4L {
    return None
  }
  // Bound memory use while allowing common EXIF, XMP, and ICC metadata blocks.
  let header_length = if size > 4_194_304L {
    4_194_304
  } else {
    Int64::to_int(size)
  }
  let file = @fs.open(path, mode=@fs.ReadOnly)
  defer file.close()
  let header = file.read_exactly_at(header_length, position=0L)
  jpeg_dimensions(header)
}

///|
async fn read_gif_dimensions(path : String, size : Int64) -> (Int, Int)? {
  if size < 13L {
    return None
  }
  let file = @fs.open(path, mode=@fs.ReadOnly)
  defer file.close()
  let header = file.read_exactly(13)
  gif_dimensions(header)
}

///|
priv enum RasterFormat {
  Png
  Jpeg
  Gif
}

///|
fn raster_format(name : String) -> RasterFormat? {
  let lower_name = name.to_lower()
  if lower_name.has_suffix(".png") {
    Some(RasterFormat::Png)
  } else if lower_name.has_suffix(".jpg") || lower_name.has_suffix(".jpeg") {
    Some(RasterFormat::Jpeg)
  } else if lower_name.has_suffix(".gif") {
    Some(RasterFormat::Gif)
  } else {
    None
  }
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

  let entries = collect_asset_files(asset_dir)
  for spec in manifest.assets {
    let mut duplicate = false
    for previous in seen_files {
      if previous == spec.file {
        duplicate = true
      }
    }
    seen_files.push(spec.file)

    if !is_safe_asset_path(spec.file) {
      results.push({
        file: spec.file,
        status: "FAIL",
        observed: "—",
        details: "file 必须是使用 / 分隔的安全相对路径，不能包含 ..、绝对路径或 Windows 分隔符",
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
    let format = match raster_format(spec.file) {
      Some(format) => format
      None => {
        results.push({
          file: spec.file,
          status: "FAIL",
          observed: "不支持的格式",
          details: "当前版本只检查 PNG、JPEG 和 GIF 图片",
        })
        continue
      }
    }

    let path = join_asset_path(asset_dir, spec.file)
    if !contains_entry(entries, spec.file) {
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
    let dimensions = match format {
      RasterFormat::Png => read_png_dimensions(path, size)
      RasterFormat::Jpeg => read_jpeg_dimensions(path, size)
      RasterFormat::Gif => read_gif_dimensions(path, size)
    }
    let observed = match dimensions {
      Some((width, height)) => "\{width} × \{height}，\{size} bytes"
      None => {
        issues.push(
          match format {
            RasterFormat::Png => "PNG 文件头无效或不完整"
            RasterFormat::Jpeg =>
              "JPEG 文件头无效、不完整或 SOF 超出 4 MiB 扫描范围"
            RasterFormat::Gif =>
              "GIF 文件头无效、不完整或尺寸为零"
          },
        )
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
    if raster_format(name) is Some(_) {
      let mut expected = false
      for spec in manifest.assets {
        if spec.file == name {
          expected = true
        }
      }
      if !expected {
        let path = join_asset_path(asset_dir, name)
        if @fs.kind(path, follow_symlink=false) == @fs.FileKind::Regular {
          let size = @fs.file_size(path)
          results.push({
            file: name,
            status: "EXTRA",
            observed: "\{size} bytes",
            details: "图片文件未列在素材清单中",
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
