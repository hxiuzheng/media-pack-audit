///|
/// Detect the actual image format from a file's leading bytes, independently of
/// its extension. This powers two checks: the manifest `format` assertion and a
/// clearer "extension does not match content" diagnostic. Detection is
/// signature-based only; it never decodes image data.

///|
pub fn detect_content_format(bytes : Bytes) -> ImageFormat? {
  if bytes.length() >= 8 && bytes.has_prefix(b"\x89PNG\r\n\x1A\n") {
    Some(ImageFormat::Png)
  } else if bytes.length() >= 6 &&
    (bytes.has_prefix(b"GIF87a") || bytes.has_prefix(b"GIF89a")) {
    Some(ImageFormat::Gif)
  } else if bytes.length() >= 2 && bytes[0] == b'B' && bytes[1] == b'M' {
    Some(ImageFormat::Bmp)
  } else if bytes.length() >= 3 &&
    bytes[0] == b'\xFF' &&
    bytes[1] == b'\xD8' &&
    bytes[2] == b'\xFF' {
    Some(ImageFormat::Jpeg)
  } else if bytes.length() >= 12 &&
    bytes.has_prefix(b"RIFF") &&
    bytes[8] == b'W' &&
    bytes[9] == b'E' &&
    bytes[10] == b'B' &&
    bytes[11] == b'P' {
    Some(ImageFormat::Webp)
  } else if bytes.length() >= 4 &&
    bytes[0] == b'I' &&
    bytes[1] == b'I' &&
    bytes[2] == b'*' &&
    bytes[3] == b'\x00' {
    Some(ImageFormat::Tiff)
  } else if bytes.length() >= 4 &&
    bytes[0] == b'M' &&
    bytes[1] == b'M' &&
    bytes[2] == b'\x00' &&
    bytes[3] == b'*' {
    Some(ImageFormat::Tiff)
  } else if bytes.length() >= 4 && bytes.has_prefix(b"8BPS") {
    Some(ImageFormat::Psd)
  } else if bytes.length() >= 12 &&
    box_type_is(bytes, 4, b"jP  ") &&
    bytes[8] == b'\x0D' &&
    bytes[9] == b'\x0A' &&
    bytes[10] == b'\x87' &&
    bytes[11] == b'\x0A' {
    Some(ImageFormat::Jp2)
  } else if bytes.length() >= 12 &&
    box_type_is(bytes, 4, b"ftyp") &&
    is_avif_brand(bytes) {
    Some(ImageFormat::Avif)
  } else if bytes.length() >= 6 &&
    bytes[0] == b'\x00' &&
    bytes[1] == b'\x00' &&
    (bytes[2] == b'\x01' || bytes[2] == b'\x02') &&
    bytes[3] == b'\x00' {
    Some(ImageFormat::Ico)
  } else if find_svg_open_tag(bytes) is Some(_) {
    Some(ImageFormat::Svg)
  } else {
    None
  }
}

///|
/// True when the `ftyp` major brand of an ISO-BMFF file is an AVIF brand.
fn is_avif_brand(bytes : Bytes) -> Bool {
  bytes[8] == b'a' &&
  bytes[9] == b'v' &&
  bytes[10] == b'i' &&
  (bytes[11] == b'f' || bytes[11] == b's')
}

///|
async fn detect_content_format_from_file(
  path : String,
  size : Int64,
) -> ImageFormat? {
  if size == 0L {
    return None
  }
  let header_length = if size > 4096L { 4096 } else { Int64::to_int(size) }
  let file = @fs.open(path, mode=@fs.ReadOnly)
  defer file.close()
  let header = file.read_exactly_at(header_length, position=0L)
  detect_content_format(header)
}

///|
/// Map a user-supplied format name (which may use a common alias) to the
/// canonical lowercase name used by `format_name`.
pub fn canonical_format(value : String) -> String? {
  match value.to_lower() {
    "png" => Some("png")
    "jpg" | "jpeg" => Some("jpeg")
    "webp" => Some("webp")
    "gif" => Some("gif")
    "bmp" => Some("bmp")
    "tif" | "tiff" => Some("tiff")
    "svg" => Some("svg")
    "avif" => Some("avif")
    "jp2" => Some("jp2")
    "ico" | "cur" => Some("ico")
    "psd" => Some("psd")
    _ => None
  }
}

///|
test "detects every supported format from its leading bytes" {
  assert_true(
    detect_content_format(b"\x89PNG\r\n\x1A\n\x00\x00\x00\x00") ==
    Some(ImageFormat::Png),
  )
  assert_true(
    detect_content_format(b"GIF89a\x00\x00\x00\x00") == Some(ImageFormat::Gif),
  )
  assert_true(
    detect_content_format(b"BM\x00\x00\x00\x00") == Some(ImageFormat::Bmp),
  )
  assert_true(
    detect_content_format(b"\xFF\xD8\xFF\xE0\x00\x00") ==
    Some(ImageFormat::Jpeg),
  )
  assert_true(
    detect_content_format(b"RIFF\x00\x00\x00\x00WEBP") ==
    Some(ImageFormat::Webp),
  )
  assert_true(
    detect_content_format(b"II*\x00\x00\x00") == Some(ImageFormat::Tiff),
  )
  assert_true(
    detect_content_format(b"MM\x00*\x00\x00") == Some(ImageFormat::Tiff),
  )
  assert_true(detect_content_format(b"8BPS\x00\x01") == Some(ImageFormat::Psd))
  assert_true(
    detect_content_format(b"\x00\x00\x01\x00\x01\x00\x00\x00") ==
    Some(ImageFormat::Ico),
  )
  assert_true(
    detect_content_format(b"\x00\x00\x00\x0CjP  \x0D\x0A\x87\x0A") ==
    Some(ImageFormat::Jp2),
  )
  assert_true(
    detect_content_format(b"\x00\x00\x00\x10ftypavif\x00\x00\x00\x00") ==
    Some(ImageFormat::Avif),
  )
  assert_true(
    detect_content_format(b"<svg width=\"10\" height=\"10\"></svg>") ==
    Some(ImageFormat::Svg),
  )
}

///|
test "does not misclassify unrelated or truncated data" {
  assert_true(detect_content_format(b"") is None)
  assert_true(detect_content_format(b"not an image") is None)
  assert_true(detect_content_format(b"\x89PN") is None)
  // A generic MP4 ftyp brand is not AVIF.
  assert_true(
    detect_content_format(b"\x00\x00\x00\x10ftypisom\x00\x00\x00\x00") is None,
  )
}

///|
test "canonicalizes format names and aliases" {
  assert_true(canonical_format("png") == Some("png"))
  assert_true(canonical_format("jpg") == Some("jpeg"))
  assert_true(canonical_format("JPEG") == Some("jpeg"))
  assert_true(canonical_format("tif") == Some("tiff"))
  assert_true(canonical_format("cur") == Some("ico"))
  assert_true(canonical_format("bogus") is None)
}
