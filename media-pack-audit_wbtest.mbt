// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "PNG CRC-32 matches the standard check vector" {
  assert_true(png_crc32(b"123456789", 0, 9) == -873187034)
}

///|
test "SHA-256 fingerprints match standard vectors across updates" {
  let empty = @crypto.SHA256::new()
  assert_true(
    @crypto.bytes_to_hex_string(empty.finalize()) ==
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
  let multipart = @crypto.SHA256::new()
  multipart.update(b"a")
  multipart.update(b"bc")
  assert_true(
    @crypto.bytes_to_hex_string(multipart.finalize()) ==
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "PNG IHDR accepts only specified field combinations" {
  assert_true(png_ihdr_fields_are_valid(1, 0, 0, 0, 0))
  assert_true(png_ihdr_fields_are_valid(16, 0, 0, 0, 1))
  assert_true(png_ihdr_fields_are_valid(8, 2, 0, 0, 0))
  assert_true(png_ihdr_fields_are_valid(16, 2, 0, 0, 0))
  assert_true(png_ihdr_fields_are_valid(4, 3, 0, 0, 0))
  assert_true(png_ihdr_fields_are_valid(8, 4, 0, 0, 0))
  assert_true(png_ihdr_fields_are_valid(16, 6, 0, 0, 1))
  assert_true(!png_ihdr_fields_are_valid(7, 6, 0, 0, 0))
  assert_true(!png_ihdr_fields_are_valid(16, 3, 0, 0, 0))
  assert_true(!png_ihdr_fields_are_valid(8, 1, 0, 0, 0))
  assert_true(!png_ihdr_fields_are_valid(8, 6, 1, 0, 0))
  assert_true(!png_ihdr_fields_are_valid(8, 6, 0, 1, 0))
  assert_true(!png_ihdr_fields_are_valid(8, 6, 0, 0, 2))
}

///|
test "accepts nested relative asset paths and rejects traversal" {
  assert_true(is_safe_asset_path("social/cover.jpeg"))
  assert_true(is_safe_asset_path("poster.png"))
  assert_true(!is_safe_asset_path("../poster.png"))
  assert_true(!is_safe_asset_path("social/../../poster.png"))
  assert_true(!is_safe_asset_path("/tmp/poster.png"))
  assert_true(!is_safe_asset_path("C:/media/poster.png"))
  assert_true(!is_safe_asset_path("social\\cover.jpeg"))
  assert_true(!is_safe_asset_path("social//cover.jpeg"))
}

///|
test "joins manifest paths using the root directory separator" {
  assert_true(
    join_asset_path("C:\\media\\assets", "social/cover.jpeg") ==
    "C:\\media\\assets\\social\\cover.jpeg",
  )
  assert_true(
    join_asset_path("/tmp/assets", "social/cover.jpeg") ==
    "/tmp/assets/social/cover.jpeg",
  )
}
