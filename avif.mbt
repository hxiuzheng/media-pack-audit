///|
/// Read primary-item canvas dimensions from AVIF / HEIF without decoding image
/// data. An `ispe` is used only when `ipma` associates it with the `pitm`
/// primary item, so a thumbnail's dimensions cannot be mistaken for the main
/// image's dimensions.

///|
pub fn avif_dimensions(bytes : Bytes) -> (Int32, Int32)? {
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
  let primary_item = match avif_primary_item_id(bytes, meta_start, meta_end) {
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
  let property_count = match
    avif_ipco_property_count(bytes, ipco_start, ipco_end) {
    Some(value) => value
    None => return None
  }
  let (ipma_start, ipma_end) = match
    find_box(bytes, iprp_start, iprp_end, b"ipma") {
    Some(value) => value
    None => return None
  }
  avif_primary_dimensions(
    bytes, ipma_start, ipma_end, ipco_start, ipco_end, property_count, primary_item,
  )
}

///|
/// Parse the primary item identifier from the `pitm` FullBox.
fn avif_primary_item_id(
  bytes : Bytes,
  meta_start : Int32,
  meta_end : Int32,
) -> Int64? {
  let (start, end) = match
    find_child_box(bytes, meta_start, meta_end, b"pitm") {
    Some(value) => value
    None => return None
  }
  if start + 4 > end ||
    bytes[start + 1] != b'\x00' ||
    bytes[start + 2] != b'\x00' ||
    bytes[start + 3] != b'\x00' {
    return None
  }
  let version = bytes[start].to_int()
  if version == 0 {
    if start + 6 != end {
      return None
    }
    Some(be_u16(bytes, start + 4))
  } else if version == 1 {
    if start + 8 != end {
      return None
    }
    Some(be_u32(bytes, start + 4))
  } else {
    None
  }
}

///|
/// Resolve the primary item's `ipma` associations to an `ispe` in `ipco`.
/// Property indexes are one-based and retain their `ipco` ordering.
fn avif_primary_dimensions(
  bytes : Bytes,
  start : Int32,
  end : Int32,
  ipco_start : Int32,
  ipco_end : Int32,
  property_count : Int64,
  primary_item : Int64,
) -> (Int32, Int32)? {
  if start + 8 > end ||
    bytes[start + 1] != b'\x00' ||
    bytes[start + 2] != b'\x00' {
    return None
  }
  let version = bytes[start].to_int()
  if version > 1 {
    return None
  }
  let flags = bytes[start + 3].to_int()
  if (flags & 0xFE) != 0 {
    return None
  }
  let wide_indexes = (flags & 1) != 0
  let entry_count = be_u32(bytes, start + 4)
  if entry_count > Int32::to_int64(end - start) {
    return None
  }
  let mut offset = start + 8
  let mut found : (Int32, Int32)? = None
  for _ in 0..<Int64::to_int(entry_count) {
    let item_id_length = if version == 0 { 2 } else { 4 }
    if offset + item_id_length + 1 > end {
      return None
    }
    let item_id = if version == 0 {
      be_u16(bytes, offset)
    } else {
      be_u32(bytes, offset)
    }
    offset = offset + item_id_length
    let association_count = bytes[offset].to_int()
    offset = offset + 1
    let association_length = if wide_indexes { 2 } else { 1 }
    if offset + association_count * association_length > end {
      return None
    }
    if item_id == primary_item {
      for _ in 0..<association_count {
        let property_index = if wide_indexes {
          be_u16(bytes, offset) & 0x7FFFL
        } else {
          Int32::to_int64(bytes[offset].to_int() & 0x7F)
        }
        offset = offset + association_length
        if property_index > property_count {
          return None
        }
        if property_index > 0L {
          let (is_ispe, width, height) = avif_ipco_dimensions(
            bytes, ipco_start, ipco_end, property_index,
          )
          if is_ispe {
            if width <= 0 || height <= 0 || found is Some(_) {
              return None
            }
            found = Some((width, height))
          }
        }
      }
    } else {
      offset = offset + association_count * association_length
    }
  }
  if offset != end {
    return None
  }
  found
}

///|
/// Validate and count all property boxes. A valid low-index property followed
/// by a malformed box must not let a truncated property container pass.
fn avif_ipco_property_count(
  bytes : Bytes,
  start : Int32,
  end : Int32,
) -> Int64? {
  let mut offset = start
  let mut count = 0L
  while offset < end {
    match box_payload(bytes, offset, end) {
      Some((_, payload_end)) => {
        if payload_end <= offset {
          return None
        }
        offset = payload_end
        count = count + 1L
      }
      None => return None
    }
  }
  Some(count)
}

///|
/// Resolve one one-based `ipco` property index. The Boolean indicates whether
/// the selected property is an `ispe` FullBox.
fn avif_ipco_dimensions(
  bytes : Bytes,
  start : Int32,
  end : Int32,
  property_index : Int64,
) -> (Bool, Int32, Int32) {
  let mut offset = start
  let mut index = 1L
  while offset < end {
    let property_start = offset
    match box_payload(bytes, offset, end) {
      Some((payload_start, payload_end)) => {
        if index == property_index {
          if !box_type_is(bytes, property_start + 4, b"ispe") {
            return (false, 0, 0)
          }
          // `ispe` is version zero with exactly two uint32 payload values.
          if payload_start + 12 != payload_end ||
            bytes[payload_start] != b'\x00' ||
            bytes[payload_start + 1] != b'\x00' ||
            bytes[payload_start + 2] != b'\x00' ||
            bytes[payload_start + 3] != b'\x00' {
            return (true, 0, 0)
          }
          let width = be_u32(bytes, payload_start + 4)
          let height = be_u32(bytes, payload_start + 8)
          if width <= 0L ||
            height <= 0L ||
            width >= 2_147_483_648L ||
            height >= 2_147_483_648L {
            return (true, 0, 0)
          }
          return (true, Int64::to_int(width), Int64::to_int(height))
        }
        offset = payload_end
        index = index + 1L
      }
      None => return (false, 0, 0)
    }
  }
  (false, 0, 0)
}

///|
/// Read a big-endian unsigned 16-bit integer.
fn be_u16(bytes : Bytes, offset : Int32) -> Int64 {
  Int32::to_int64(bytes[offset].to_int()) * 256L +
  Int32::to_int64(bytes[offset + 1].to_int())
}

///|
async fn read_avif_dimensions(path : String, size : Int64) -> (Int32, Int32)? {
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
test "reads AVIF dimensions through the primary item's ispe association" {
  // pitm identifies item 1; ipma associates property 1 (the ispe) with it.
  let ispe : Bytes = b"\x00\x00\x00\x14ispe\x00\x00\x00\x00\x00\x00\x02\x58\x00\x00\x01\x0E"
  let ipco : Bytes = b"\x00\x00\x00\x1Cipco" + ispe
  let ipma : Bytes = b"\x00\x00\x00\x14ipma\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01\x01\x01"
  let iprp : Bytes = b"\x00\x00\x00\x38iprp" + ipco + ipma
  let pitm : Bytes = b"\x00\x00\x00\x0Epitm\x00\x00\x00\x00\x00\x01"
  let meta : Bytes = b"\x00\x00\x00\x52meta\x00\x00\x00\x00" + pitm + iprp
  let bytes : Bytes = b"\x00\x00\x00\x10ftypavif\x00\x00\x00\x00" + meta
  assert_true(avif_dimensions(bytes) == Some((600, 270)))
}

///|
test "selects the primary item's ispe rather than an earlier thumbnail" {
  let thumbnail : Bytes = b"\x00\x00\x00\x14ispe\x00\x00\x00\x00\x00\x00\x00\x20\x00\x00\x00\x20"
  let primary : Bytes = b"\x00\x00\x00\x14ispe\x00\x00\x00\x00\x00\x00\x03\x20\x00\x00\x01\x68"
  let ipco : Bytes = b"\x00\x00\x00\x30ipco" + thumbnail + primary
  let ipma : Bytes = b"\x00\x00\x00\x18ipma\x00\x00\x00\x00\x00\x00\x00\x02\x00\x01\x01\x01\x00\x02\x01\x02"
  let iprp : Bytes = b"\x00\x00\x00\x50iprp" + ipco + ipma
  let pitm : Bytes = b"\x00\x00\x00\x0Epitm\x00\x00\x00\x00\x00\x02"
  let meta : Bytes = b"\x00\x00\x00\x6Ameta\x00\x00\x00\x00" + pitm + iprp
  let bytes : Bytes = b"\x00\x00\x00\x10ftypavif\x00\x00\x00\x00" + meta
  assert_true(avif_dimensions(bytes) == Some((800, 360)))
}

///|
test "rejects AVIF files that are not ISO-BMFF or lack the ispe box" {
  assert_true(avif_dimensions(b"not an avif") is None)
  let no_ispe : Bytes = b"\x00\x00\x00\x10ftypavif\x00\x00\x00\x00" +
    b"\x00\x00\x00\x08free"
  assert_true(avif_dimensions(no_ispe) is None)
  let unassociated : Bytes = b"\x00\x00\x00\x10ftypavif\x00\x00\x00\x00" +
    b"\x00\x00\x00\x52meta\x00\x00\x00\x00" +
    b"\x00\x00\x00\x0Epitm\x00\x00\x00\x00\x00\x01" +
    b"\x00\x00\x00\x38iprp" +
    b"\x00\x00\x00\x1Cipco" +
    b"\x00\x00\x00\x14ispe\x00\x00\x00\x00\x00\x00\x02\x58\x00\x00\x01\x0E" +
    b"\x00\x00\x00\x14ipma\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01\x01\x00"
  assert_true(avif_dimensions(unassociated) is None)
  let bad_ftyp : Bytes = b"\x00\x00\x00\x08noty\x00\x00\x00\x00"
  assert_true(avif_dimensions(bad_ftyp) is None)
}
