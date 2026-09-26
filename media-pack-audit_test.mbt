///|
test "reads a valid PNG IHDR size" {
  let png : Bytes = b"\x89PNG\r\n\x1A\n\x00\x00\x00\x0DIHDR\x00\x00\x00\x04\x00\x00\x00\x03\x08\x06\x00\x00\x00\xB4\xF4\xAE\xC6"
  assert_true(@media-pack-audit.png_dimensions(png) == Some((4, 3)))
}

///|
test "rejects PNG with a corrupted IHDR checksum" {
  let png : Bytes = b"\x89PNG\r\n\x1A\n\x00\x00\x00\x0DIHDR\x00\x00\x00\x04\x00\x00\x00\x03\x08\x06\x00\x00\x00\xB4\xF4\xAE\xC7"
  assert_true(@media-pack-audit.png_dimensions(png) is None)
}

///|
test "rejects invalid IHDR fields even when their checksum is correct" {
  let png : Bytes = b"\x89PNG\r\n\x1A\n\x00\x00\x00\x0DIHDR\x00\x00\x00\x04\x00\x00\x00\x03\x07\x06\x00\x00\x00\x36\xA4\x39\x17"
  assert_true(@media-pack-audit.png_dimensions(png) is None)
}

///|
test "rejects short and non-PNG data" {
  assert_true(@media-pack-audit.png_dimensions(b"not an image") is None)
  let not_png : Bytes = b"\x00PNG\r\n\x1A\n\x00\x00\x00\x0DIHDR\x00\x00\x00\x02\x00\x00\x00\x03\x08\x06\x00\x00\x00\x00\x00\x00\x00"
  assert_true(@media-pack-audit.png_dimensions(not_png) is None)
}

///|
test "reads baseline JPEG dimensions after metadata segments" {
  let jpeg : Bytes = b"\xFF\xD8\xFF\xE0\x00\x04\x01\x02\xFF\xC0\x00\x11\x08\x00\x03\x00\x04\x03\x01\x11\x00\x02\x11\x01\x03\x11\x01"
  assert_true(@media-pack-audit.jpeg_dimensions(jpeg) == Some((4, 3)))
}

///|
test "reads progressive JPEG dimensions with fill bytes" {
  let jpeg : Bytes = b"\xFF\xD8\xFF\xFF\xC2\x00\x0B\x08\x00\x09\x00\x10\x01\x01\x11\x00"
  assert_true(@media-pack-audit.jpeg_dimensions(jpeg) == Some((16, 9)))
}

///|
test "applies EXIF display orientation to JPEG dimensions" {
  let little_endian : Bytes = b"\xFF\xD8\xFF\xE1\x00\x22Exif\x00\x00II\x2A\x00\x08\x00\x00\x00\x01\x00\x12\x01\x03\x00\x01\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\x00\xFF\xC0\x00\x11\x08\x00\x03\x00\x04\x03\x01\x11\x00\x02\x11\x01\x03\x11\x01"
  let big_endian : Bytes = b"\xFF\xD8\xFF\xE1\x00\x22Exif\x00\x00MM\x00\x2A\x00\x00\x00\x08\x00\x01\x01\x12\x00\x03\x00\x00\x00\x01\x00\x08\x00\x00\x00\x00\x00\x00\xFF\xC0\x00\x11\x08\x00\x03\x00\x04\x03\x01\x11\x00\x02\x11\x01\x03\x11\x01"
  assert_true(@media-pack-audit.jpeg_dimensions(little_endian) == Some((3, 4)))
  assert_true(@media-pack-audit.jpeg_dimensions(big_endian) == Some((3, 4)))
}

///|
test "ignores malformed EXIF orientation and keeps JPEG SOF dimensions" {
  let invalid_orientation : Bytes = b"\xFF\xD8\xFF\xE1\x00\x22Exif\x00\x00II\x2A\x00\x08\x00\x00\x00\x01\x00\x12\x01\x03\x00\x01\x00\x00\x00\x09\x00\x00\x00\x00\x00\x00\x00\xFF\xC0\x00\x11\x08\x00\x03\x00\x04\x03\x01\x11\x00\x02\x11\x01\x03\x11\x01"
  assert_true(
    @media-pack-audit.jpeg_dimensions(invalid_orientation) == Some((4, 3)),
  )
}

///|
test "rejects malformed JPEG markers and frame lengths" {
  assert_true(@media-pack-audit.jpeg_dimensions(b"not a JPEG") is None)
  let truncated : Bytes = b"\xFF\xD8\xFF\xC0\x00\x11\x08\x00\x03\x00\x04"
  assert_true(@media-pack-audit.jpeg_dimensions(truncated) is None)
  let malformed_length : Bytes = b"\xFF\xD8\xFF\xC0\x00\x07\x08\x00\x03\x00\x04\x01"
  assert_true(@media-pack-audit.jpeg_dimensions(malformed_length) is None)
}

///|
test "reads GIF87a and GIF89a logical screen dimensions" {
  let gif87a : Bytes = b"GIF87a\x04\x00\x03\x00\x00\x00\x00"
  let gif89a : Bytes = b"GIF89a\x10\x00\x09\x00\x00\x00\x00"
  assert_true(@media-pack-audit.gif_dimensions(gif87a) == Some((4, 3)))
  assert_true(@media-pack-audit.gif_dimensions(gif89a) == Some((16, 9)))
}

///|
test "rejects malformed and zero-sized GIF headers" {
  assert_true(@media-pack-audit.gif_dimensions(b"not a GIF") is None)
  assert_true(
    @media-pack-audit.gif_dimensions(b"GIF90a\x04\x00\x03\x00\x00\x00\x00")
    is None,
  )
  assert_true(
    @media-pack-audit.gif_dimensions(b"GIF87a\x00\x00\x03\x00\x00\x00\x00")
    is None,
  )
  assert_true(@media-pack-audit.gif_dimensions(b"GIF87a\x04\x00\x03") is None)
}

///|
test "reads BITMAPINFOHEADER BMP dimensions" {
  let bmp : Bytes = b"BM\x36\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00\x04\x00\x00\x00\x03\x00\x00\x00"
  assert_true(@media-pack-audit.bmp_dimensions(bmp) == Some((4, 3)))
}

///|
test "reports absolute height for top-down BMP" {
  let bmp : Bytes = b"BM\x36\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00\x04\x00\x00\x00\xFD\xFF\xFF\xFF"
  assert_true(@media-pack-audit.bmp_dimensions(bmp) == Some((4, 3)))
}

///|
test "reads BITMAPCOREHEADER BMP dimensions" {
  let bmp : Bytes = b"BM\x36\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x0C\x00\x00\x00\x04\x00\x03\x00\x00\x00\x00\x00"
  assert_true(@media-pack-audit.bmp_dimensions(bmp) == Some((4, 3)))
}

///|
test "rejects malformed and zero-sized BMP headers" {
  assert_true(@media-pack-audit.bmp_dimensions(b"not a BMP") is None)
  let not_bm : Bytes = b"XX\x36\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00\x04\x00\x00\x00\x03\x00\x00\x00"
  assert_true(@media-pack-audit.bmp_dimensions(not_bm) is None)
  let bad_dib : Bytes = b"BM\x36\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x08\x00\x00\x00\x04\x00\x00\x00\x03\x00\x00\x00"
  assert_true(@media-pack-audit.bmp_dimensions(bad_dib) is None)
  let zero_width : Bytes = b"BM\x36\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00"
  assert_true(@media-pack-audit.bmp_dimensions(zero_width) is None)
}

///|
test "reads little-endian SHORT TIFF dimensions" {
  let tiff : Bytes = b"II\x2A\x00\x08\x00\x00\x00\x02\x00\x00\x01\x03\x00\x01\x00\x00\x00\x04\x00\x00\x00\x01\x01\x03\x00\x01\x00\x00\x00\x03\x00\x00\x00"
  assert_true(@media-pack-audit.tiff_dimensions(tiff) == Some((4, 3)))
}

///|
test "reads big-endian LONG TIFF dimensions" {
  let tiff : Bytes = b"MM\x00\x2A\x00\x00\x00\x08\x00\x02\x01\x00\x00\x04\x00\x00\x00\x01\x00\x00\x00\x10\x01\x01\x00\x04\x00\x00\x00\x01\x00\x00\x00\x09"
  assert_true(@media-pack-audit.tiff_dimensions(tiff) == Some((16, 9)))
}

///|
test "rejects malformed TIFF headers and missing dimension tags" {
  assert_true(@media-pack-audit.tiff_dimensions(b"not a TIFF") is None)
  assert_true(
    @media-pack-audit.tiff_dimensions(b"XX\x2A\x00\x08\x00\x00\x00\x00\x00")
    is None,
  )
  assert_true(
    @media-pack-audit.tiff_dimensions(b"II\x00\x00\x08\x00\x00\x00\x00\x00")
    is None,
  )
  assert_true(
    @media-pack-audit.tiff_dimensions(b"II\x2A\x00\x08\x00\x00\x00\x00\x00")
    is None,
  )
}

///|
test "parses aspect ratio strings" {
  assert_true(@media-pack-audit.parse_aspect("16:9") == Some((16, 9)))
  assert_true(@media-pack-audit.parse_aspect("4:3") == Some((4, 3)))
  assert_true(@media-pack-audit.parse_aspect("1:1") == Some((1, 1)))
  assert_true(@media-pack-audit.parse_aspect("16") is None)
  assert_true(@media-pack-audit.parse_aspect(":9") is None)
  assert_true(@media-pack-audit.parse_aspect("16:") is None)
  assert_true(@media-pack-audit.parse_aspect("a:b") is None)
  assert_true(@media-pack-audit.parse_aspect("16:0") is None)
}

///|
test "matches aspect ratio by exact cross-multiplication" {
  assert_true(@media-pack-audit.matches_aspect(1920, 1080, 16, 9))
  assert_true(@media-pack-audit.matches_aspect(1600, 900, 16, 9))
  assert_true(@media-pack-audit.matches_aspect(100, 100, 1, 1))
  assert_false(@media-pack-audit.matches_aspect(1200, 630, 16, 9))
  assert_false(@media-pack-audit.matches_aspect(1080, 1920, 16, 9))
}

///|
test "escapes HTML special characters" {
  assert_true(
    @media-pack-audit.html_escape("<&>\"'") == "&lt;&amp;&gt;&quot;&#39;",
  )
}
