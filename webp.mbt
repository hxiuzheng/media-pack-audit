///|
/// Read the canvas dimensions from the first simple or extended WebP header.
/// The caller supplies the full file size because this function receives only a
/// short prefix, not the compressed image data.
pub fn webp_dimensions(bytes : Bytes, file_size : Int64) -> (Int, Int)? {
  if bytes.length() < 20 || file_size < 20L {
    return None
  }
  if bytes[0] != b'R' ||
    bytes[1] != b'I' ||
    bytes[2] != b'F' ||
    bytes[3] != b'F' ||
    bytes[8] != b'W' ||
    bytes[9] != b'E' ||
    bytes[10] != b'B' ||
    bytes[11] != b'P' {
    return None
  }
  if read_webp_u32(bytes, 4) + 8L != file_size {
    return None
  }

  let chunk_size = read_webp_u32(bytes, 16)
  let padded_chunk_size = chunk_size + (chunk_size & 1L)
  if padded_chunk_size > file_size - 20L {
    return None
  }

  if webp_chunk_type_is(bytes, 12, b"VP8X") {
    if chunk_size != 10L || bytes.length() < 30 {
      return None
    }
    if (bytes[20].to_int() & 0xC1) != 0 ||
      bytes[21] != b'\x00' ||
      bytes[22] != b'\x00' ||
      bytes[23] != b'\x00' {
      return None
    }
    let width = read_webp_u24(bytes, 24) + 1
    let height = read_webp_u24(bytes, 27) + 1
    if Int::to_int64(width) * Int::to_int64(height) > 4_294_967_295L {
      return None
    }
    return Some((width, height))
  }

  if webp_chunk_type_is(bytes, 12, b"VP8L") {
    if chunk_size < 5L || bytes.length() < 25 || bytes[20] != b'\x2F' {
      return None
    }
    let width = bytes[21].to_int() + (bytes[22].to_int() & 0x3F) * 256 + 1
    let height = ((bytes[22].to_int() >> 6) & 0x03) +
      bytes[23].to_int() * 4 +
      (bytes[24].to_int() & 0x0F) * 1024 +
      1
    if bytes[24].to_int() >> 5 != 0 {
      return None
    }
    return Some((width, height))
  }

  if webp_chunk_type_is(bytes, 12, b"VP8 ") {
    if chunk_size < 10L || bytes.length() < 30 {
      return None
    }
    if (bytes[20].to_int() & 1) != 0 ||
      bytes[23] != b'\x9D' ||
      bytes[24] != b'\x01' ||
      bytes[25] != b'\x2A' {
      return None
    }
    let width = read_little_endian_u16(bytes, 26) & 0x3FFF
    let height = read_little_endian_u16(bytes, 28) & 0x3FFF
    if width > 0 && height > 0 {
      return Some((width, height))
    }
  }
  None
}

///|
async fn read_webp_dimensions(path : String, size : Int64) -> (Int, Int)? {
  if size < 20L {
    return None
  }
  let header_length = if size > 30L { 30 } else { Int64::to_int(size) }
  let file = @fs.open(path, mode=@fs.ReadOnly)
  defer file.close()
  let header = file.read_exactly_at(header_length, position=0L)
  match webp_dimensions(header, size) {
    Some(dimensions) => {
      let complete = webp_chunks_are_valid(file, size) catch { _ => false }
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
/// Check RIFF chunk bounds and padding without decoding WebP image data.
async fn webp_chunks_are_valid(file : @fs.File, size : Int64) -> Bool {
  if size < 20L {
    return false
  }
  let header = file.read_exactly_at(12, position=0L)
  if header[0] != b'R' ||
    header[1] != b'I' ||
    header[2] != b'F' ||
    header[3] != b'F' ||
    header[8] != b'W' ||
    header[9] != b'E' ||
    header[10] != b'B' ||
    header[11] != b'P' ||
    read_webp_u32(header, 4) + 8L != size {
    return false
  }

  let mut offset = 12L
  let mut first_chunk = true
  let mut extended = false
  let mut has_image_data = false
  while offset < size {
    if size - offset < 8L {
      return false
    }
    let chunk_header = file.read_exactly_at(8, position=offset)
    let chunk_size = read_webp_u32(chunk_header, 4)
    let padded_chunk_size = chunk_size + (chunk_size & 1L)
    if padded_chunk_size > size - offset - 8L {
      return false
    }

    let is_extended = webp_chunk_type_is(chunk_header, 0, b"VP8X")
    let is_lossy = webp_chunk_type_is(chunk_header, 0, b"VP8 ")
    let is_lossless = webp_chunk_type_is(chunk_header, 0, b"VP8L")
    let is_animation_frame = webp_chunk_type_is(chunk_header, 0, b"ANMF")
    if first_chunk {
      extended = is_extended
      if !is_extended && !is_lossy && !is_lossless {
        return false
      }
      if is_extended && chunk_size != 10L {
        return false
      }
      if (is_lossy && chunk_size < 10L) || (is_lossless && chunk_size < 5L) {
        return false
      }
    } else if is_extended || !extended {
      return false
    }
    if (is_lossy && chunk_size >= 10L) || (is_lossless && chunk_size >= 5L) {
      has_image_data = true
    }
    if is_animation_frame && chunk_size >= 16L {
      has_image_data = true
    }

    if (chunk_size & 1L) != 0 {
      let padding = file.read_exactly_at(1, position=offset + 8L + chunk_size)
      if padding[0] != b'\x00' {
        return false
      }
    }
    offset += 8L + padded_chunk_size
    first_chunk = false
  }

  !first_chunk && has_image_data && (extended || offset == size)
}

///|
fn read_webp_u24(bytes : Bytes, offset : Int) -> Int {
  bytes[offset].to_int() +
  bytes[offset + 1].to_int() * 256 +
  bytes[offset + 2].to_int() * 65_536
}

///|
fn read_webp_u32(bytes : Bytes, offset : Int) -> Int64 {
  Int::to_int64(bytes[offset].to_int()) +
  Int::to_int64(bytes[offset + 1].to_int()) * 256L +
  Int::to_int64(bytes[offset + 2].to_int()) * 65_536L +
  Int::to_int64(bytes[offset + 3].to_int()) * 16_777_216L
}

///|
fn webp_chunk_type_is(bytes : Bytes, offset : Int, name : Bytes) -> Bool {
  bytes[offset] == name[0] &&
  bytes[offset + 1] == name[1] &&
  bytes[offset + 2] == name[2] &&
  bytes[offset + 3] == name[3]
}

///|
test "reads WebP lossless image dimensions" {
  let webp : Bytes = b"RIFF\x12\x00\x00\x00WEBPVP8L\x05\x00\x00\x00\x2F\x03\x80\x00\x00\x00"
  assert_true(webp_dimensions(webp, 26L) == Some((4, 3)))
}

///|
test "reads WebP lossy key frame dimensions" {
  let webp : Bytes = b"RIFF\x1E\x00\x00\x00WEBPVP8 \x0A\x00\x00\x00\x00\x00\x00\x9D\x01\x2A\x10\x00\x09\x00"
  assert_true(webp_dimensions(webp, 38L) == Some((16, 9)))
}

///|
test "reads extended WebP canvas dimensions" {
  let webp : Bytes = b"RIFF\x16\x00\x00\x00WEBPVP8X\x0A\x00\x00\x00\x00\x00\x00\x00\xAF\x04\x00\x75\x02\x00"
  assert_true(webp_dimensions(webp, 30L) == Some((1200, 630)))
}

///|
test "rejects malformed WebP headers and unsupported lossless versions" {
  assert_true(webp_dimensions(b"not a WebP", 10L) is None)
  let bad_riff_length : Bytes = b"RIFF\x13\x00\x00\x00WEBPVP8X\x0A\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  assert_true(webp_dimensions(bad_riff_length, 30L) is None)
  let bad_version : Bytes = b"RIFF\x12\x00\x00\x00WEBPVP8L\x05\x00\x00\x00\x2F\x03\x80\x00\x20\x00"
  assert_true(webp_dimensions(bad_version, 26L) is None)
}
