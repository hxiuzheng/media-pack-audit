// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

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
