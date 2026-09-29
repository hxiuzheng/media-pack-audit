///|
/// Read the canvas dimensions from an SVG document without rendering it. SVG
/// stores its viewport either as `width`/`height` attributes (which may carry
/// CSS units) or as a `viewBox="min-x min-y width height"` fallback. Only
/// integer-valued dimensions are reported, because the manifest compares exact
/// integer pixel sizes; fractional or unit-relative sizes are rejected.

///|
pub fn svg_dimensions(bytes : Bytes) -> (Int, Int)? {
  let tag_start = match find_svg_open_tag(bytes) {
    Some(offset) => offset
    None => return None
  }
  let tag_end = match find_tag_end(bytes, tag_start) {
    Some(offset) => offset
    None => return None
  }
  let width = find_attribute_int(bytes, tag_start, tag_end, b"width")
  let height = find_attribute_int(bytes, tag_start, tag_end, b"height")
  match (width, height) {
    (Some(w), Some(h)) => Some((w, h))
    _ =>
      match find_attribute(bytes, tag_start, tag_end, b"viewBox") {
        Some((value_start, value_end)) =>
          parse_viewbox_wh(bytes, value_start, value_end)
        None => None
      }
  }
}

///|
fn find_svg_open_tag(bytes : Bytes) -> Int? {
  let end = bytes.length()
  let mut index = 0
  while index + 4 <= end {
    if bytes[index] == b'<' &&
      ascii_eq_ci(bytes[index + 1], b's') &&
      ascii_eq_ci(bytes[index + 2], b'v') &&
      ascii_eq_ci(bytes[index + 3], b'g') &&
      (index + 4 == end || is_svg_tag_boundary(bytes[index + 4])) {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn is_svg_tag_boundary(byte : Byte) -> Bool {
  is_space(byte) || byte == b'>' || byte == b'/'
}

///|
/// Find the closing `>` of the tag that starts at `tag_start`, skipping `>`
/// characters that appear inside quoted attribute values.
fn find_tag_end(bytes : Bytes, tag_start : Int) -> Int? {
  let end = bytes.length()
  let mut index = tag_start + 1
  let mut quote : Byte? = None
  while index < end {
    let current = bytes[index]
    match quote {
      Some(quoted) => if current == quoted { quote = None }
      None =>
        if current == b'"' || current == b'\'' {
          quote = Some(current)
        } else if current == b'>' {
          return Some(index)
        }
    }
    index += 1
  }
  None
}

///|
/// Locate an attribute by name and return the range of its quoted value.
fn find_attribute(
  bytes : Bytes,
  tag_start : Int,
  tag_end : Int,
  name : Bytes,
) -> (Int, Int)? {
  let name_length = name.length()
  let mut index = tag_start + 1
  while index + name_length <= tag_end {
    if attribute_name_is(bytes, index, name) {
      let mut after_name = index + name_length
      while after_name < tag_end && is_space(bytes[after_name]) {
        after_name += 1
      }
      if after_name < tag_end && bytes[after_name] == b'=' {
        after_name += 1
        while after_name < tag_end && is_space(bytes[after_name]) {
          after_name += 1
        }
        if after_name < tag_end &&
          (bytes[after_name] == b'"' || bytes[after_name] == b'\'') {
          let quote = bytes[after_name]
          let value_start = after_name + 1
          let mut value_end = value_start
          while value_end < tag_end && bytes[value_end] != quote {
            value_end += 1
          }
          if value_end < tag_end {
            return Some((value_start, value_end))
          }
        }
      }
    }
    index += 1
  }
  None
}

///|
fn find_attribute_int(
  bytes : Bytes,
  tag_start : Int,
  tag_end : Int,
  name : Bytes,
) -> Int? {
  match find_attribute(bytes, tag_start, tag_end, name) {
    Some((value_start, value_end)) =>
      parse_svg_int(bytes, value_start, value_end)
    None => None
  }
}

///|
/// An attribute name must be preceded by whitespace so that substrings of a
/// longer name (for example `maxwidth`) do not match.
fn attribute_name_is(bytes : Bytes, offset : Int, name : Bytes) -> Bool {
  if offset == 0 || !is_space(bytes[offset - 1]) {
    return false
  }
  for index in 0..<name.length() {
    if !ascii_eq_ci(bytes[offset + index], name[index]) {
      return false
    }
  }
  true
}

///|
/// Parse a non-negative integer from an SVG length value. A trailing unit
/// (`px`, `%`, `em`, …) is ignored. Fractional values that are not exactly
/// integral are rejected because they cannot be represented by the integer
/// manifest.
fn parse_svg_int(bytes : Bytes, start : Int, end : Int) -> Int? {
  let mut index = start
  while index < end && is_space(bytes[index]) {
    index += 1
  }
  if index >= end {
    return None
  }
  let mut negative = false
  if bytes[index] == b'-' {
    negative = true
    index += 1
  } else if bytes[index] == b'+' {
    index += 1
  }
  let mut value = 0
  let mut saw_digit = false
  while index < end && is_digit(bytes[index]) {
    value = value * 10 + (bytes[index].to_int() - 48)
    saw_digit = true
    index += 1
  }
  if !saw_digit {
    return None
  }
  if index < end && bytes[index] == b'.' {
    index += 1
    while index < end && is_digit(bytes[index]) {
      if bytes[index] != b'0' {
        return None
      }
      index += 1
    }
  }
  if negative || value <= 0 {
    None
  } else {
    Some(value)
  }
}

///|
/// Parse the third and fourth numbers of a `viewBox` value as width and height.
fn parse_viewbox_wh(bytes : Bytes, start : Int, end : Int) -> (Int, Int)? {
  let mut position = start
  let values : Array[Int] = []
  while values.length() < 4 {
    while position < end &&
          (is_space(bytes[position]) || bytes[position] == b',') {
      position += 1
    }
    let mut negative = false
    if position < end && (bytes[position] == b'-' || bytes[position] == b'+') {
      negative = bytes[position] == b'-'
      position += 1
    }
    let mut value = 0
    let mut saw_digit = false
    while position < end && is_digit(bytes[position]) {
      value = value * 10 + (bytes[position].to_int() - 48)
      saw_digit = true
      position += 1
    }
    if position < end && bytes[position] == b'.' {
      position += 1
      while position < end && is_digit(bytes[position]) {
        if bytes[position] != b'0' {
          return None
        }
        position += 1
      }
    }
    if !saw_digit {
      return None
    }
    values.push(if negative { -value } else { value })
  }
  let width = values[2]
  let height = values[3]
  if width > 0 && height > 0 {
    Some((width, height))
  } else {
    None
  }
}

///|
fn ascii_eq_ci(left : Byte, right : Byte) -> Bool {
  if left == right {
    return true
  }
  let lower_left = if left >= b'A' && left <= b'Z' {
    left.to_int() + 32
  } else {
    left.to_int()
  }
  let lower_right = if right >= b'A' && right <= b'Z' {
    right.to_int() + 32
  } else {
    right.to_int()
  }
  lower_left == lower_right
}

///|
fn is_space(byte : Byte) -> Bool {
  byte == b' ' || byte == b'\t' || byte == b'\n' || byte == b'\r'
}

///|
fn is_digit(byte : Byte) -> Bool {
  byte >= b'0' && byte <= b'9'
}

///|
async fn read_svg_dimensions(path : String, size : Int64) -> (Int, Int)? {
  if size == 0L {
    return None
  }
  // The root <svg> tag and its width/height/viewBox normally appear at the top
  // of the document; bound the read to keep memory use predictable.
  let header_length = if size > 65_536L { 65_536 } else { Int64::to_int(size) }
  let file = @fs.open(path, mode=@fs.ReadOnly)
  defer file.close()
  let header = file.read_exactly_at(header_length, position=0L)
  svg_dimensions(header)
}

///|
test "reads SVG width and height attributes with and without units" {
  assert_true(
    svg_dimensions(b"<svg width=\"1200\" height=\"630\"></svg>") ==
    Some((1200, 630)),
  )
  assert_true(
    svg_dimensions(b"<svg width=\"1200px\" height=\"630px\"></svg>") ==
    Some((1200, 630)),
  )
}

///|
test "falls back to the SVG viewBox when width or height is missing" {
  assert_true(
    svg_dimensions(b"<svg viewBox=\"0 0 800 600\"></svg>") == Some((800, 600)),
  )
  assert_true(
    svg_dimensions(
      b"<?xml version=\"1.0\"?><svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"10,20,640,480\"></svg>",
    ) ==
    Some((640, 480)),
  )
}

///|
test "matches the svg tag case-insensitively" {
  assert_true(
    svg_dimensions(b"<SVG width=\"64\" height=\"64\"/>") == Some((64, 64)),
  )
}

///|
test "rejects SVG without usable integer dimensions" {
  assert_true(svg_dimensions(b"<html></html>") is None)
  assert_true(svg_dimensions(b"<svg width=\"1.5\" height=\"2\"></svg>") is None)
  assert_true(svg_dimensions(b"<svg></svg>") is None)
  assert_true(svg_dimensions(b"<svg viewBox=\"0 0 -8 6\"></svg>") is None)
  assert_true(
    svg_dimensions(b"<svg width=\"auto\" height=\"auto\"></svg>") is None,
  )
}
