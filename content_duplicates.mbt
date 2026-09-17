///|
/// Register a successfully calculated content digest and return the first file
/// that used the same digest, if one was already seen.
fn register_content_digest(
  seen : Map[String, String],
  file : String,
  digest : String,
) -> String? {
  if digest == "—" {
    return None
  }
  match seen.get(digest) {
    Some(previous_file) => Some(previous_file)
    None => {
      seen[digest] = file
      None
    }
  }
}

///|
test "content digest matching stays informational and keeps the first path" {
  let seen : Map[String, String] = Map([])
  assert_true(register_content_digest(seen, "original.webp", "abc") is None)
  assert_true(
    register_content_digest(seen, "copy.webp", "abc") == Some("original.webp"),
  )
  assert_true(
    register_content_digest(seen, "another-copy.webp", "abc") ==
    Some("original.webp"),
  )
  assert_true(register_content_digest(seen, "unhashed.webp", "—") is None)
  assert_true(!seen.contains("—"))
}
