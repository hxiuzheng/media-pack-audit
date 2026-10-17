///|
/// Validate typed constraints as well as JSON-decoded ones. Public callers can
/// construct AssetSpec directly, so scan_assets must not rely on the parser.
fn asset_spec_error(spec : AssetSpec) -> String? {
  if spec.max_bytes <= 0 {
    return Some("max_bytes 必须为正整数")
  }
  let dimensions_are_valid = match (spec.width, spec.height) {
    (Some(width), Some(height)) => width > 0 && height > 0
    (None, None) => true
    _ => false
  }
  if !dimensions_are_valid {
    return Some("width 和 height 必须同时省略或同时为正整数")
  }
  match spec.min_bytes {
    Some(minimum) if minimum <= 0 => return Some("min_bytes 必须为正整数")
    Some(minimum) if minimum > spec.max_bytes =>
      return Some("min_bytes 不能大于 max_bytes")
    _ => ()
  }
  match spec.expected_sha256 {
    Some(expected) => {
      if expected.length() != 64 {
        return Some("expected_sha256 必须是 64 位十六进制字符串")
      }
      for character in expected {
        if !is_hex_character(character) {
          return Some("expected_sha256 必须是 64 位十六进制字符串")
        }
      }
    }
    None => ()
  }
  match spec.aspect {
    Some(aspect) if parse_aspect(aspect) is None =>
      return Some("aspect 必须是 W:H 形式的正整数比例")
    _ => ()
  }
  match spec.format {
    Some(format) if canonical_format(format) is None =>
      return Some(
        "format 必须是受支持的格式名（如 png、jpeg、webp、svg）",
      )
    _ => ()
  }
  None
}
