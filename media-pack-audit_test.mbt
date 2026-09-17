///|
test "reads a valid PNG IHDR size" {
  let png : Bytes = b"\x89PNG\r\n\x1A\n\x00\x00\x00\x0DIHDR\x00\x00\x00\x04\x00\x00\x00\x03\x08\x06\x00\x00\x00\xB4\xF4\xAE\xC6"
  assert_true(png_dimensions(png) == Some((4, 3)))
}

///|
test "rejects PNG with a corrupted IHDR checksum" {
  let png : Bytes = b"\x89PNG\r\n\x1A\n\x00\x00\x00\x0DIHDR\x00\x00\x00\x04\x00\x00\x00\x03\x08\x06\x00\x00\x00\xB4\xF4\xAE\xC7"
  assert_true(png_dimensions(png) is None)
}

///|
test "rejects short and non-PNG data" {
  assert_true(png_dimensions(b"not an image") is None)
  let not_png : Bytes = b"\x00PNG\r\n\x1A\n\x00\x00\x00\x0DIHDR\x00\x00\x00\x02\x00\x00\x00\x03\x08\x06\x00\x00\x00\x00\x00\x00\x00"
  assert_true(png_dimensions(not_png) is None)
}

///|
test "reads baseline JPEG dimensions after metadata segments" {
  let jpeg : Bytes = b"\xFF\xD8\xFF\xE0\x00\x04\x01\x02\xFF\xC0\x00\x11\x08\x00\x03\x00\x04\x03\x01\x11\x00\x02\x11\x01\x03\x11\x01"
  assert_true(jpeg_dimensions(jpeg) == Some((4, 3)))
}

///|
test "reads progressive JPEG dimensions with fill bytes" {
  let jpeg : Bytes = b"\xFF\xD8\xFF\xFF\xC2\x00\x0B\x08\x00\x09\x00\x10\x01\x01\x11\x00"
  assert_true(jpeg_dimensions(jpeg) == Some((16, 9)))
}

///|
test "rejects malformed JPEG markers and frame lengths" {
  assert_true(jpeg_dimensions(b"not a JPEG") is None)
  let truncated : Bytes = b"\xFF\xD8\xFF\xC0\x00\x11\x08\x00\x03\x00\x04"
  assert_true(jpeg_dimensions(truncated) is None)
  let malformed_length : Bytes = b"\xFF\xD8\xFF\xC0\x00\x07\x08\x00\x03\x00\x04\x01"
  assert_true(jpeg_dimensions(malformed_length) is None)
}

///|
test "reads GIF87a and GIF89a logical screen dimensions" {
  let gif87a : Bytes = b"GIF87a\x04\x00\x03\x00\x00\x00\x00"
  let gif89a : Bytes = b"GIF89a\x10\x00\x09\x00\x00\x00\x00"
  assert_true(gif_dimensions(gif87a) == Some((4, 3)))
  assert_true(gif_dimensions(gif89a) == Some((16, 9)))
}

///|
test "rejects malformed and zero-sized GIF headers" {
  assert_true(gif_dimensions(b"not a GIF") is None)
  assert_true(gif_dimensions(b"GIF90a\x04\x00\x03\x00\x00\x00\x00") is None)
  assert_true(gif_dimensions(b"GIF87a\x00\x00\x03\x00\x00\x00\x00") is None)
  assert_true(gif_dimensions(b"GIF87a\x04\x00\x03") is None)
}

///|
test "escapes HTML special characters" {
  assert_true(html_escape("<&>\"'") == "&lt;&amp;&gt;&quot;&#39;")
}
