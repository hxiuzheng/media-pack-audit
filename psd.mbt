///|
/// Read the canvas dimensions from a Photoshop PSD / PSB header without decoding
/// any layer or pixel data. Width and height are stored big-endian near the top
/// of the file.

///|
pub fn psd_dimensions(bytes : Bytes) -> (Int, Int)? {
  if bytes.length() < 22 {
    return None
  }
  if !bytes.has_prefix(b"8BPS") {
    return None
  }
  // Version must be 1 (PSD); PSB uses version 2 and larger values, which this
  // reader intentionally does not accept because PSB uses 64-bit dimensions.
  if bytes[4].to_int() != 0 || bytes[5].to_int() != 1 {
    return None
  }
  let channels = read_big_endian_u16(bytes, 12)
  if channels < 1 || channels > 56 {
    return None
  }
  let height = read_big_endian_u32(bytes, 14)
  let width = read_big_endian_u32(bytes, 18)
  if width <= 0L ||
    height <= 0L ||
    width >= 2_147_483_648L ||
    height >= 2_147_483_648L {
    return None
  }
  Some((Int64::to_int(width), Int64::to_int(height)))
}

///|
async fn read_psd_dimensions(path : String, size : Int64) -> (Int, Int)? {
  if size < 22L {
    return None
  }
  let file = @fs.open(path, mode=@fs.ReadOnly)
  defer file.close()
  let header = file.read_exactly(22)
  psd_dimensions(header)
}

///|
test "reads PSD width and height from the header" {
  // 8BPS, version 1, 6 reserved bytes, 4 channels, height 40, width 64
  let psd : Bytes = b"8BPS\x00\x01\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x28\x00\x00\x00\x40"
  assert_true(psd_dimensions(psd) == Some((64, 40)))
}

///|
test "rejects malformed PSD headers" {
  assert_true(psd_dimensions(b"not a psd") is None)
  // wrong version (2 = PSB)
  let psb : Bytes = b"8BPS\x00\x02\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x28\x00\x00\x00\x40"
  assert_true(psd_dimensions(psb) is None)
  // zero channels
  let no_channels : Bytes = b"8BPS\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x28\x00\x00\x00\x40"
  assert_true(psd_dimensions(no_channels) is None)
  let short : Bytes = b"8BPS\x00\x01"
  assert_true(psd_dimensions(short) is None)
}
