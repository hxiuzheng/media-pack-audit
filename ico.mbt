///|
/// Read the first-image dimensions from a Windows ICO or CUR container without
/// decoding any bitmap data. The width and height are stored as single bytes in
/// the first directory entry, where 0 means 256 pixels.

///|
pub fn ico_dimensions(bytes : Bytes) -> (Int, Int)? {
  if bytes.length() < 22 {
    return None
  }
  if read_little_endian_u16(bytes, 0) != 0 {
    return None
  }
  let image_type = read_little_endian_u16(bytes, 2)
  if image_type != 1 && image_type != 2 {
    return None
  }
  let entry_count = read_little_endian_u16(bytes, 4)
  if entry_count == 0 {
    return None
  }
  let width = bytes[6].to_int()
  let height = bytes[7].to_int()
  let resolved_width = if width == 0 { 256 } else { width }
  let resolved_height = if height == 0 { 256 } else { height }
  if resolved_width > 0 && resolved_height > 0 {
    Some((resolved_width, resolved_height))
  } else {
    None
  }
}

///|
async fn read_ico_dimensions(path : String, size : Int64) -> (Int, Int)? {
  if size < 22L {
    return None
  }
  let file = @fs.open(path, mode=@fs.ReadOnly)
  defer file.close()
  let header = file.read_exactly(22)
  ico_dimensions(header)
}

///|
test "reads ICO and CUR first-entry dimensions including the 256 case" {
  // reserved=0, type=1(icon), count=1, width=16, height=16
  let icon : Bytes = b"\x00\x00\x01\x00\x01\x00\x10\x10\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  assert_true(ico_dimensions(icon) == Some((16, 16)))
  // width=0 means 256
  let large : Bytes = b"\x00\x00\x01\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  assert_true(ico_dimensions(large) == Some((256, 256)))
  // type=2 cursor
  let cursor : Bytes = b"\x00\x00\x02\x00\x01\x00\x20\x20\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  assert_true(ico_dimensions(cursor) == Some((32, 32)))
}

///|
test "rejects malformed ICO/CUR headers" {
  assert_true(ico_dimensions(b"not an icon") is None)
  let bad_type : Bytes = b"\x00\x00\x03\x00\x01\x00\x10\x10\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  assert_true(ico_dimensions(bad_type) is None)
  let zero_count : Bytes = b"\x00\x00\x01\x00\x00\x00\x10\x10\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  assert_true(ico_dimensions(zero_count) is None)
  let short : Bytes = b"\x00\x00\x01\x00\x01"
  assert_true(ico_dimensions(short) is None)
}
