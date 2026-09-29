///|
/// Read the image dimensions from a JPEG 2000 (JP2) file without decoding the
/// code stream. The dimensions live in the `ihdr` (Image Header) box inside the
/// top-level `jp2h` header box.

///|
pub fn jp2_dimensions(bytes : Bytes) -> (Int, Int)? {
  let end = bytes.length()
  // The file must start with the JPEG 2000 signature box (type "jP  ") whose
  // payload is the fixed 0x0D0A870A signature.
  if end < 12 ||
    !box_type_is(bytes, 4, b"jP  ") ||
    bytes[8] != b'\x0D' ||
    bytes[9] != b'\x0A' ||
    bytes[10] != b'\x87' ||
    bytes[11] != b'\x0A' {
    return None
  }

  let (jp2h_start, jp2h_end) = match find_box(bytes, 0, end, b"jp2h") {
    Some(value) => value
    None => return None
  }
  // `jp2h` is a plain box (no version/flags), so its children start right away.
  let (ihdr_start, ihdr_end) = match
    find_box(bytes, jp2h_start, jp2h_end, b"ihdr") {
    Some(value) => value
    None => return None
  }
  // `ihdr` payload: height(4) width(4) components(2) bpc(1) compression(1) ...
  if ihdr_start + 8 > ihdr_end {
    return None
  }
  let height = be_u32(bytes, ihdr_start)
  let width = be_u32(bytes, ihdr_start + 4)
  if width <= 0L ||
    height <= 0L ||
    width >= 2_147_483_648L ||
    height >= 2_147_483_648L {
    return None
  }
  Some((Int64::to_int(width), Int64::to_int(height)))
}

///|
async fn read_jp2_dimensions(path : String, size : Int64) -> (Int, Int)? {
  if size < 12L {
    return None
  }
  // The `jp2h`/`ihdr` boxes normally sit near the front of the file; bound the
  // read to keep memory use predictable.
  let header_length = if size > 4_194_304L {
    4_194_304
  } else {
    Int64::to_int(size)
  }
  let file = @fs.open(path, mode=@fs.ReadOnly)
  defer file.close()
  let header = file.read_exactly_at(header_length, position=0L)
  jp2_dimensions(header)
}

///|
test "reads JP2 dimensions from the jp2h/ihdr boxes" {
  let ihdr : Bytes = b"\x00\x00\x00\x16ihdr\x00\x00\x00\x18\x00\x00\x00\x20\x00\x03\x08\x07\x00\x00"
  let jp2h : Bytes = b"\x00\x00\x00\x1Ejp2h" + ihdr
  let bytes : Bytes = b"\x00\x00\x00\x0CjP  \x0D\x0A\x87\x0A" +
    b"\x00\x00\x00\x14ftypjp2 \x00\x00\x00\x00jp2 " +
    jp2h
  assert_true(jp2_dimensions(bytes) == Some((32, 24)))
}

///|
test "rejects JP2 files that are not JPEG 2000 or lack the ihdr box" {
  assert_true(jp2_dimensions(b"not a jp2") is None)
  let no_ihdr : Bytes = b"\x00\x00\x00\x0CjP  \x0D\x0A\x87\x0A" +
    b"\x00\x00\x00\x10jp2h\x00\x00\x00\x08free"
  assert_true(jp2_dimensions(no_ihdr) is None)
  let bad_signature : Bytes = b"\x00\x00\x00\x0CjP  \x0D\x0A\x87\x0B" +
    b"\x00\x00\x00\x10jp2h\x00\x00\x00\x08free"
  assert_true(jp2_dimensions(bad_signature) is None)
}
