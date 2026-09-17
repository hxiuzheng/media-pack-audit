///|
test "reads a valid PNG IHDR size" {
  let png : Bytes = b"\x89PNG\r\n\x1A\n\x00\x00\x00\x0DIHDR\x00\x00\x00\x02\x00\x00\x00\x03\x08\x06\x00\x00\x00\x00\x00\x00\x00"
  assert_true(png_dimensions(png) == Some((2, 3)))
}

///|
test "rejects short and non-PNG data" {
  assert_true(png_dimensions(b"not an image") is None)
  let not_png : Bytes = b"\x00PNG\r\n\x1A\n\x00\x00\x00\x0DIHDR\x00\x00\x00\x02\x00\x00\x00\x03\x08\x06\x00\x00\x00\x00\x00\x00\x00"
  assert_true(png_dimensions(not_png) is None)
}

///|
test "escapes HTML special characters" {
  assert_true(html_escape("<&>\"'") == "&lt;&amp;&gt;&quot;&#39;")
}
