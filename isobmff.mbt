///|
/// Minimal ISO Base Media File Format (ISOBMFF / ISO/IEC 14496-12) box walker.
/// AVIF (HEIF) and JPEG 2000 both store their image dimensions inside nested
/// boxes, so they share this bounded, size-checked reader. It never decodes
/// image data; it only follows the box size/type framing.

///|
/// Read a big-endian unsigned 32-bit integer.
fn be_u32(bytes : Bytes, offset : Int) -> Int64 {
  Int::to_int64(bytes[offset].to_int()) * 16_777_216L +
  Int::to_int64(bytes[offset + 1].to_int()) * 65_536L +
  Int::to_int64(bytes[offset + 2].to_int()) * 256L +
  Int::to_int64(bytes[offset + 3].to_int())
}

///|
/// Read a big-endian unsigned 64-bit integer (used for the `largesize` field).
fn be_u64(bytes : Bytes, offset : Int) -> Int64 {
  be_u32(bytes, offset) * 4_294_967_296L + be_u32(bytes, offset + 4)
}

///|
/// True when the four bytes at `offset` spell the given box type tag.
fn box_type_is(bytes : Bytes, offset : Int, name : Bytes) -> Bool {
  bytes[offset] == name[0] &&
  bytes[offset + 1] == name[1] &&
  bytes[offset + 2] == name[2] &&
  bytes[offset + 3] == name[3]
}

///|
/// Return the payload range `(payload_start, payload_end)` of the box whose
/// header starts at `offset`. `payload_end` is also the offset of the next
/// sibling box. Returns `None` when the header or declared size is malformed
/// or runs past `end`.
fn box_payload(bytes : Bytes, offset : Int, end : Int) -> (Int, Int)? {
  if offset + 8 > end {
    return None
  }
  let size32 = be_u32(bytes, offset)
  let mut header_len = 8
  let size = if size32 == 1L {
    if offset + 16 > end {
      return None
    }
    header_len = 16
    be_u64(bytes, offset + 8)
  } else if size32 == 0L {
    Int::to_int64(end - offset)
  } else {
    size32
  }
  let remaining = Int::to_int64(end - offset)
  if size < Int::to_int64(header_len) || size > remaining {
    return None
  }
  let size_int = Int64::to_int(size)
  Some((offset + header_len, offset + size_int))
}

///|
/// Scan sibling boxes from `start` up to `end` and return the payload range of
/// the first box whose type tag matches `name`. Non-matching boxes are skipped
/// using their declared size, so malformed framing fails the whole walk.
fn find_box(bytes : Bytes, start : Int, end : Int, name : Bytes) -> (Int, Int)? {
  let mut offset = start
  while offset < end {
    match box_payload(bytes, offset, end) {
      Some((payload_start, payload_end)) => {
        if box_type_is(bytes, offset + 4, name) {
          return Some((payload_start, payload_end))
        }
        offset = payload_end
      }
      None => return None
    }
  }
  None
}

///|
/// Find a box nested inside a FullBox parent. The parent payload starts with a
/// 4-byte version/flags field, so children begin at `parent_start + 4`.
fn find_child_box(
  bytes : Bytes,
  parent_start : Int,
  parent_end : Int,
  name : Bytes,
) -> (Int, Int)? {
  if parent_start + 4 > parent_end {
    return None
  }
  find_box(bytes, parent_start + 4, parent_end, name)
}

///|
test "walks sibling boxes and skips non-matching entries" {
  // box "aaaa" size 8 (empty), box "bbbb" size 12 payload "1234"
  let bytes : Bytes = b"\x00\x00\x00\x08aaaa\x00\x00\x00\x0Cbbbb1234"
  assert_true(find_box(bytes, 0, bytes.length(), b"bbbb") == Some((16, 20)))
  assert_true(find_box(bytes, 0, bytes.length(), b"cccc") is None)
}

///|
test "rejects boxes whose declared size overruns the buffer" {
  let bytes : Bytes = b"\x00\x00\x00\x20abcd"
  assert_true(find_box(bytes, 0, bytes.length(), b"abcd") is None)
  let short : Bytes = b"\x00\x00\x00\x08"
  assert_true(box_payload(short, 0, short.length()) is None)
}

///|
test "supports a box that extends to the end of the file" {
  let bytes : Bytes = b"\x00\x00\x00\x00abcdhello"
  assert_true(find_box(bytes, 0, bytes.length(), b"abcd") == Some((8, 13)))
}
