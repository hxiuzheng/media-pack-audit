///|
/// Read the canvas dimensions from an AVIF / HEIF file without decoding image
/// data. The dimensions live in the `ispe` (Image Spatial Extents) property,
/// reached through the nested `meta` → `iprp` → `ipco` box chain described by
/// the HEIF / ISOBMFF container structure.

///|
pub fn avif_dimensions(bytes : Bytes) -> (Int, Int)? {
  let end = bytes.length()
  // The first box must be a `ftyp` brand box, otherwise this is not an
  // ISO-BMFF-based image.
  match box_payload(bytes, 0, end) {
    Some(_) => if !box_type_is(bytes, 4, b"ftyp") { return None }
    None => return None
  }

  // `meta` is a FullBox, so its children start after the 4-byte version/flags.
  let (meta_start, meta_end) = match find_box(bytes, 0, end, b"meta") {
    Some(value) => value
    None => return None
  }
  let (iprp_start, iprp_end) = match
    find_child_box(bytes, meta_start, meta_end, b"iprp") {
    Some(value) => value
    None => return None
  }
  // `iprp` and `ipco` are plain boxes (no version/flags), so their children
  // start right at the payload boundary.
  let (ipco_start, ipco_end) = match
    find_box(bytes, iprp_start, iprp_end, b"ipco") {
    Some(value) => value
    None => return None
  }
  let (ispe_start, ispe_end) = match
    find_box(bytes, ipco_start, ipco_end, b"ispe") {
    Some(value) => value
    None => return None
  }
  // `ispe` is a FullBox: 4-byte version/flags, then 32-bit width and height.
  if ispe_start + 12 > ispe_end {
    return None
  }
  let width = be_u32(bytes, ispe_start + 4)
  let height = be_u32(bytes, ispe_start + 8)
  if width <= 0L ||
    height <= 0L ||
    width >= 2_147_483_648L ||
    height >= 2_147_483_648L {
    return None
  }
  Some((Int64::to_int(width), Int64::to_int(height)))
}

///|
async fn read_avif_dimensions(path : String, size : Int64) -> (Int, Int)? {
  if size < 12L {
    return None
  }
  // The `meta` box and its `ispe` property normally sit near the front of the
  // file; bound the read to keep memory use predictable.
  let header_length = if size > 4_194_304L {
    4_194_304
  } else {
    Int64::to_int(size)
  }
  let file = @fs.open(path, mode=@fs.ReadOnly)
  defer file.close()
  let header = file.read_exactly_at(header_length, position=0L)
  avif_dimensions(header)
}

///|
test "reads AVIF dimensions from the ispe property box" {
  // ispe (FullBox), ipco (plain), iprp (plain), meta (FullBox)
  let ispe : Bytes = b"\x00\x00\x00\x14ispe\x00\x00\x00\x00\x00\x00\x02\x58\x00\x00\x01\x0E"
  let ipco : Bytes = b"\x00\x00\x00\x1Cipco" + ispe
  let iprp : Bytes = b"\x00\x00\x00\x24iprp" + ipco
  let meta : Bytes = b"\x00\x00\x00\x30meta\x00\x00\x00\x00" + iprp
  let bytes : Bytes = b"\x00\x00\x00\x10ftypavif\x00\x00\x00\x00" + meta
  assert_true(avif_dimensions(bytes) == Some((600, 270)))
}

///|
test "rejects AVIF files that are not ISO-BMFF or lack the ispe box" {
  assert_true(avif_dimensions(b"not an avif") is None)
  let no_ispe : Bytes = b"\x00\x00\x00\x10ftypavif\x00\x00\x00\x00" +
    b"\x00\x00\x00\x08free"
  assert_true(avif_dimensions(no_ispe) is None)
  let bad_ftyp : Bytes = b"\x00\x00\x00\x08noty\x00\x00\x00\x00"
  assert_true(avif_dimensions(bad_ftyp) is None)
}
