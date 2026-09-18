///|
pub(all) struct AssetSpec {
  file : String
  label : String?
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
  label : String?
  status : String
  observed : String
  sha256 : String
  details : String
} derive(ToJson)

///|
pub(all) struct AuditReport {
  asset_dir : String
  manifest_sha256 : String
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
  if !png_ihdr_fields_are_valid(
      bytes[24].to_int(),
      bytes[25].to_int(),
      bytes[26].to_int(),
      bytes[27].to_int(),
      bytes[28].to_int(),
    ) {
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
  png_crc_matches(crc, bytes, 29)
}

///|
/// CRC-32/ISO-HDLC as used by PNG chunks.
fn png_crc32(bytes : Bytes, start : Int, end : Int) -> Int {
  png_crc32_update(-1, bytes, start, end) ^ -1
}

///|
fn png_crc32_update(crc : Int, bytes : Bytes, start : Int, end : Int) -> Int {
  let mut result = crc
  for index in start..<end {
    result = result ^ bytes[index].to_int()
    result = ((result >> 4) & 0x0FFFFFFF) ^ png_crc32_nibble(result & 0x0F)
    result = ((result >> 4) & 0x0FFFFFFF) ^ png_crc32_nibble(result & 0x0F)
  }
  result
}

///|
fn png_crc32_nibble(nibble : Int) -> Int {
  match nibble {
    0 => 0x00000000
    1 => 0x1DB71064
    2 => 0x3B6E20C8
    3 => 0x26D930AC
    4 => 0x76DC4190
    5 => 0x6B6B51F4
    6 => 0x4DB26158
    7 => 0x5005713C
    8 => 0xEDB88320
    9 => 0xF00F9344
    10 => 0xD6D6A3E8
    11 => 0xCB61B38C
    12 => 0x9B64C2B0
    13 => 0x86D3D2D4
    14 => 0xA00AE278
    15 => 0xBDBDF21C
    _ => 0
  }
}

///|
fn png_crc_matches(crc : Int, bytes : Bytes, offset : Int) -> Bool {
  bytes[offset].to_int() == ((crc >> 24) & 0xFF) &&
  bytes[offset + 1].to_int() == ((crc >> 16) & 0xFF) &&
  bytes[offset + 2].to_int() == ((crc >> 8) & 0xFF) &&
  bytes[offset + 3].to_int() == (crc & 0xFF)
}

///|
/// Check the combinations defined by the PNG IHDR specification.
fn png_ihdr_fields_are_valid(
  bit_depth : Int,
  color_type : Int,
  compression_method : Int,
  filter_method : Int,
  interlace_method : Int,
) -> Bool {
  let valid_bit_depth = match color_type {
    0 =>
      bit_depth == 1 ||
      bit_depth == 2 ||
      bit_depth == 4 ||
      bit_depth == 8 ||
      bit_depth == 16
    2 => bit_depth == 8 || bit_depth == 16
    3 => bit_depth == 1 || bit_depth == 2 || bit_depth == 4 || bit_depth == 8
    4 | 6 => bit_depth == 8 || bit_depth == 16
    _ => false
  }
  valid_bit_depth &&
  compression_method == 0 &&
  filter_method == 0 &&
  (interlace_method == 0 || interlace_method == 1)
}

///|
pub fn jpeg_dimensions(bytes : Bytes) -> (Int, Int)? {
  if bytes.length() < 4 || bytes[0] != b'\xFF' || bytes[1] != b'\xD8' {
    return None
  }

  let mut offset = 2
  let mut orientation : Int? = None
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
    if marker == b'\xE1' && orientation is None {
      orientation = jpeg_exif_orientation(bytes, offset + 2, segment_length - 2)
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
        match orientation {
          Some(value) if value >= 5 && value <= 8 =>
            return Some((height, width))
          _ => return Some((width, height))
        }
      }
      return None
    }
    offset += segment_length
  }
  None
}

///|
/// Read the EXIF Orientation tag from a JPEG APP1 payload. Invalid or
/// unsupported EXIF metadata is ignored so the SOF dimensions remain usable.
fn jpeg_exif_orientation(
  bytes : Bytes,
  payload_start : Int,
  payload_length : Int,
) -> Int? {
  if payload_start < 0 ||
    payload_length < 32 ||
    payload_start > bytes.length() - payload_length {
    return None
  }
  if bytes[payload_start] != b'E' ||
    bytes[payload_start + 1] != b'x' ||
    bytes[payload_start + 2] != b'i' ||
    bytes[payload_start + 3] != b'f' ||
    bytes[payload_start + 4] != b'\x00' ||
    bytes[payload_start + 5] != b'\x00' {
    return None
  }

  let tiff_start = payload_start + 6
  let payload_end = payload_start + payload_length
  let little_endian = if bytes[tiff_start] == b'I' &&
    bytes[tiff_start + 1] == b'I' {
    true
  } else if bytes[tiff_start] == b'M' && bytes[tiff_start + 1] == b'M' {
    false
  } else {
    return None
  }
  if read_tiff_u16(bytes, tiff_start + 2, little_endian) != 42 {
    return None
  }
  let ifd_offset = match
    read_tiff_u32_bounded(bytes, tiff_start + 4, payload_end, little_endian) {
    Some(value) if value >= 8 => value
    _ => return None
  }
  let ifd_start = tiff_start + ifd_offset
  if ifd_start + 2 > payload_end {
    return None
  }
  let entry_count = read_tiff_u16(bytes, ifd_start, little_endian)
  let entries_start = ifd_start + 2
  let entry_bytes = entry_count * 12
  if entry_bytes + 4 > payload_end - entries_start {
    return None
  }
  for entry_index in 0..<entry_count {
    let entry_start = entries_start + entry_index * 12
    let tag = read_tiff_u16(bytes, entry_start, little_endian)
    let field_type = read_tiff_u16(bytes, entry_start + 2, little_endian)
    if tag == 274 &&
      field_type == 3 &&
      tiff_u32_is_one(bytes, entry_start + 4, little_endian) {
      let value = read_tiff_u16(bytes, entry_start + 8, little_endian)
      if value >= 1 && value <= 8 {
        return Some(value)
      }
    }
  }
  None
}

///|
fn read_tiff_u16(bytes : Bytes, offset : Int, little_endian : Bool) -> Int {
  if little_endian {
    read_little_endian_u16(bytes, offset)
  } else {
    read_big_endian_u16(bytes, offset)
  }
}

///|
/// TIFF offsets must fit within a JPEG APP1 segment (at most 64 KiB).
fn read_tiff_u32_bounded(
  bytes : Bytes,
  offset : Int,
  end : Int,
  little_endian : Bool,
) -> Int? {
  if offset < 0 || offset + 4 > end {
    return None
  }
  if little_endian {
    if bytes[offset + 2] != b'\x00' || bytes[offset + 3] != b'\x00' {
      return None
    }
    Some(read_little_endian_u16(bytes, offset))
  } else {
    if bytes[offset] != b'\x00' || bytes[offset + 1] != b'\x00' {
      return None
    }
    Some(read_big_endian_u16(bytes, offset + 2))
  }
}

///|
fn tiff_u32_is_one(bytes : Bytes, offset : Int, little_endian : Bool) -> Bool {
  if little_endian {
    bytes[offset] == b'\x01' &&
    bytes[offset + 1] == b'\x00' &&
    bytes[offset + 2] == b'\x00' &&
    bytes[offset + 3] == b'\x00'
  } else {
    bytes[offset] == b'\x00' &&
    bytes[offset + 1] == b'\x00' &&
    bytes[offset + 2] == b'\x00' &&
    bytes[offset + 3] == b'\x01'
  }
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
async fn sha256_file(path : String, size : Int64) -> String? {
  let file = @fs.open(path, mode=@fs.ReadOnly)
  defer file.close()
  let hasher = @crypto.SHA256::new()
  let mut offset = 0L
  while offset < size {
    let remaining = size - offset
    let block_size = if remaining > 65_536L {
      65_536
    } else {
      Int64::to_int(remaining)
    }
    let block = file.read_exactly_at(block_size, position=offset)
    hasher.update(block)
    offset += Int::to_int64(block_size)
  }
  if @fs.file_size(path) != size {
    return None
  }
  Some(@crypto.bytes_to_hex_string(hasher.finalize()))
}

///|
/// Fingerprint the exact manifest bytes so a saved report can be tied to the
/// specification file used for the audit.
pub fn sha256_bytes(bytes : Bytes) -> String {
  let hasher = @crypto.SHA256::new()
  hasher.update(bytes)
  @crypto.bytes_to_hex_string(hasher.finalize())
}

///|
async fn read_png_dimensions(path : String, size : Int64) -> (Int, Int)? {
  if size < Int::to_int64(33) {
    return None
  }
  let file = @fs.open(path, mode=@fs.ReadOnly)
  defer file.close()
  let header = file.read_exactly_at(33, position=0L)
  match png_dimensions(header) {
    Some(dimensions) => {
      let complete = png_chunks_are_valid(file, size) catch { _ => false }
      if complete {
        Some(dimensions)
      } else {
        None
      }
    }
    None => None
  }
}

///|
/// Check PNG chunk framing and CRCs without decompressing image data.
async fn png_chunks_are_valid(file : @fs.File, size : Int64) -> Bool {
  if size < 8L {
    return false
  }
  let signature = file.read_exactly_at(8, position=0L)
  if !signature.has_prefix(b"\x89PNG\r\n\x1A\n") {
    return false
  }

  let mut offset = 8L
  let mut chunk_index = 0
  let mut has_idat = false
  let mut idat_sequence_ended = false
  while offset < size {
    if size - offset < 12L {
      return false
    }
    let header = file.read_exactly_at(8, position=offset)
    let length = read_png_chunk_length(header)
    if length > 2_147_483_647L || length > size - offset - 12L {
      return false
    }
    if !is_png_chunk_type(header, 4) {
      return false
    }

    let is_ihdr = png_chunk_type_is(header, b"IHDR")
    let is_idat = png_chunk_type_is(header, b"IDAT")
    let is_iend = png_chunk_type_is(header, b"IEND")
    if chunk_index == 0 {
      if !is_ihdr || length != 13L {
        return false
      }
    } else if is_ihdr {
      return false
    }
    if is_idat {
      if idat_sequence_ended {
        return false
      }
      has_idat = true
    } else if has_idat && !is_iend {
      idat_sequence_ended = true
    }
    if is_iend && (!has_idat || length != 0L) {
      return false
    }

    let mut crc = png_crc32_update(-1, header, 4, 8)
    let data_start = offset + 8L
    let data_end = data_start + length
    let mut data_offset = data_start
    while data_offset < data_end {
      let remaining = data_end - data_offset
      let block_size = if remaining > 65_536L {
        65_536
      } else {
        Int64::to_int(remaining)
      }
      let block = file.read_exactly_at(block_size, position=data_offset)
      crc = png_crc32_update(crc, block, 0, block.length())
      data_offset += Int::to_int64(block_size)
    }
    crc = crc ^ -1
    let stored_crc = file.read_exactly_at(4, position=data_end)
    if !png_crc_matches(crc, stored_crc, 0) {
      return false
    }

    offset = data_end + 4L
    chunk_index += 1
    if is_iend {
      return offset == size
    }
  }
  false
}

///|
fn read_png_chunk_length(bytes : Bytes) -> Int64 {
  Int::to_int64(bytes[0].to_int()) * 16_777_216L +
  Int::to_int64(bytes[1].to_int()) * 65_536L +
  Int::to_int64(bytes[2].to_int()) * 256L +
  Int::to_int64(bytes[3].to_int())
}

///|
fn is_png_chunk_type(bytes : Bytes, offset : Int) -> Bool {
  for index in offset..<(offset + 4) {
    let value = bytes[index].to_int()
    let is_uppercase = value >= b'A'.to_int() && value <= b'Z'.to_int()
    let is_lowercase = value >= b'a'.to_int() && value <= b'z'.to_int()
    if !is_uppercase && !is_lowercase {
      return false
    }
  }
  // The reserved bit (bit 5 of the third type byte) must be zero.
  bytes[offset + 2].to_int() >= b'A'.to_int() &&
  bytes[offset + 2].to_int() <= b'Z'.to_int()
}

///|
fn png_chunk_type_is(bytes : Bytes, name : Bytes) -> Bool {
  bytes[4] == name[0] &&
  bytes[5] == name[1] &&
  bytes[6] == name[2] &&
  bytes[7] == name[3]
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
  Webp
  Gif
}

///|
fn raster_format(name : String) -> RasterFormat? {
  let lower_name = name.to_lower()
  if lower_name.has_suffix(".png") {
    Some(RasterFormat::Png)
  } else if lower_name.has_suffix(".jpg") || lower_name.has_suffix(".jpeg") {
    Some(RasterFormat::Jpeg)
  } else if lower_name.has_suffix(".webp") {
    Some(RasterFormat::Webp)
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
  manifest_sha256 : String,
) -> AuditReport {
  let results : Array[CheckResult] = []
  let seen_files : Array[String] = []
  let seen_digests : Map[String, String] = Map([])

  if manifest.assets.is_empty() {
    results.push({
      file: "<manifest>",
      label: None,
      status: "FAIL",
      observed: "0 项",
      sha256: "—",
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
        label: spec.label,
        status: "FAIL",
        observed: "—",
        sha256: "—",
        details: "file 必须是使用 / 分隔的安全相对路径，不能包含 ..、绝对路径或 Windows 分隔符",
      })
      continue
    }
    if duplicate {
      results.push({
        file: spec.file,
        label: spec.label,
        status: "FAIL",
        observed: "重复项",
        sha256: "—",
        details: "清单中出现了重复文件名",
      })
      continue
    }
    if spec.width <= 0 || spec.height <= 0 || spec.max_bytes <= 0 {
      results.push({
        file: spec.file,
        label: spec.label,
        status: "FAIL",
        observed: "—",
        sha256: "—",
        details: "宽、高和 max_bytes 必须为正数",
      })
      continue
    }
    let format = match raster_format(spec.file) {
      Some(format) => format
      None => {
        results.push({
          file: spec.file,
          label: spec.label,
          status: "FAIL",
          observed: "不支持的格式",
          sha256: "—",
          details: "当前版本只检查 PNG、JPEG、WebP 和 GIF 图片",
        })
        continue
      }
    }

    let path = join_asset_path(asset_dir, spec.file)
    if !contains_entry(entries, spec.file) {
      results.push({
        file: spec.file,
        label: spec.label,
        status: "FAIL",
        observed: "缺失",
        sha256: "—",
        details: "清单要求的文件名（含大小写）没有交付",
      })
      continue
    }
    let kind = @fs.kind(path, follow_symlink=false)
    if kind != @fs.FileKind::Regular {
      results.push({
        file: spec.file,
        label: spec.label,
        status: "FAIL",
        observed: "非普通文件",
        sha256: "—",
        details: "清单路径必须指向普通文件",
      })
      continue
    }

    let size = @fs.file_size(path)
    let issues : Array[String] = []
    let max_bytes = Int::to_int64(spec.max_bytes)
    if size > max_bytes {
      issues.push("文件大小 \{size} bytes 超出上限 \{max_bytes} bytes")
    }
    let digest = if size <= max_bytes {
      sha256_file(path, size) catch {
        _ => None
      }
    } else {
      None
    }
    let (sha256, hash_failed) = match digest {
      Some(value) => (value, false)
      None => ("—", size <= max_bytes)
    }
    if hash_failed {
      issues.push(
        "SHA-256 计算失败或文件大小在检查期间发生变化",
      )
    }
    let dimensions = match format {
      RasterFormat::Png => read_png_dimensions(path, size)
      RasterFormat::Jpeg => read_jpeg_dimensions(path, size)
      RasterFormat::Webp => read_webp_dimensions(path, size)
      RasterFormat::Gif => read_gif_dimensions(path, size)
    }
    let observed = match dimensions {
      Some((width, height)) => "\{width} × \{height}，\{size} bytes"
      None => {
        issues.push(
          match format {
            RasterFormat::Png =>
              "PNG 结构无效、不完整或 CRC 校验失败"
            RasterFormat::Jpeg =>
              "JPEG 文件头无效、不完整或 SOF 超出 4 MiB 扫描范围"
            RasterFormat::Webp =>
              "WebP RIFF 结构无效、不完整或尺寸头错误"
            RasterFormat::Gif =>
              "GIF 文件头无效、不完整或尺寸为零"
          },
        )
        "\{size} bytes"
      }
    }
    match dimensions {
      Some((width, height)) if width != spec.width || height != spec.height =>
        issues.push(
          "尺寸不匹配（清单要求 \{spec.width} × \{spec.height}，实际 \{width} × \{height}）",
        )
      _ => ()
    }
    let status = if issues.is_empty() { "PASS" } else { "FAIL" }
    let issue_details = if issues.is_empty() {
      "符合清单规格"
    } else {
      issues.join("；")
    }
    let duplicate_details = match
      register_content_digest(seen_digests, spec.file, sha256) {
      Some(previous_file) =>
        "SHA-256 与 \{previous_file} 相同，可能是重复导出，请人工确认"
      None => ""
    }
    let details = if duplicate_details == "" {
      issue_details
    } else if issues.is_empty() {
      duplicate_details
    } else {
      "\{issue_details}；\{duplicate_details}"
    }
    results.push({
      file: spec.file,
      label: spec.label,
      status,
      observed,
      sha256,
      details,
    })
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
          let digest = sha256_file(path, size) catch { _ => None }
          let sha256 = match digest {
            Some(value) => value
            None => "—"
          }
          let details = match
            register_content_digest(seen_digests, name, sha256) {
            Some(previous_file) =>
              "图片文件未列在素材清单中；SHA-256 与 \{previous_file} 相同，可能是重复导出，请人工确认"
            None => "图片文件未列在素材清单中"
          }
          results.push({
            file: name,
            label: None,
            status: "EXTRA",
            observed: "\{size} bytes",
            sha256,
            details,
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
  {
    asset_dir,
    manifest_sha256,
    checked: results.length(),
    passed,
    failed,
    results,
  }
}
