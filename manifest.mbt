///|
/// Generate a starter media-pack.json from an existing asset directory. This
/// helps a human start a handoff: for every supported image it records the
/// detected dimensions and a size budget, so the result can be edited and then
/// passed straight to `check`. Unreadable or unsupported files are reported
/// back so the caller can explain why they were skipped.

///|
pub(all) struct ScaffoldResult {
  manifest : String
  generated : Int
  skipped : Array[String]
}

///|
pub async fn scaffold_manifest(asset_dir : String) -> ScaffoldResult {
  let entries = collect_asset_files(asset_dir)
  let generated_entries : Array[String] = []
  let skipped : Array[String] = []
  for name in entries {
    match image_format(name) {
      Some(format) => {
        let path = join_asset_path(asset_dir, name)
        if @fs.kind(path, follow_symlink=false) == @fs.FileKind::Regular {
          let size = @fs.file_size(path)
          match read_image_dimensions(format, path, size) {
            Some((width, height)) => {
              let max_bytes = if size > 512L {
                Int64::to_int(size) * 2
              } else {
                1024
              }
              generated_entries.push(
                render_asset_entry(name, width, height, max_bytes),
              )
            }
            None => skipped.push(name)
          }
        }
      }
      None => ()
    }
  }
  let manifest = if generated_entries.is_empty() {
    "{\n  \"assets\": []\n}\n"
  } else {
    "{\n  \"assets\": [\n" + generated_entries.join(",\n") + "\n  ]\n}\n"
  }
  { manifest, generated: generated_entries.length(), skipped, }
}

///|
fn render_asset_entry(
  file : String,
  width : Int,
  height : Int,
  max_bytes : Int,
) -> String {
  "    {\n      \"file\": \"\{json_escape(file)}\",\n      \"width\": \{width},\n      \"height\": \{height},\n      \"max_bytes\": \{max_bytes}\n    }"
}

///|
/// Escape a string for inclusion in a JSON string literal.
fn json_escape(value : String) -> String {
  let output = StringBuilder()
  for character in value {
    match character {
      '"' => output <+ "\\\""
      '\\' => output <+ "\\\\"
      '\n' => output <+ "\\n"
      '\r' => output <+ "\\r"
      '\t' => output <+ "\\t"
      _ => output <+ "\{character}"
    }
  }
  output.to_string()
}

///|
test "escapes JSON string special characters" {
  assert_true(json_escape("a\"b\\c") == "a\\\"b\\\\c")
  assert_true(json_escape("line\nbreak") == "line\\nbreak")
  assert_true(json_escape("plain") == "plain")
}

///|
test "renders a deterministic asset entry" {
  assert_true(
    render_asset_entry("social/cover.jpeg", 1200, 630, 2048) ==
    "    {\n      \"file\": \"social/cover.jpeg\",\n      \"width\": 1200,\n      \"height\": 630,\n      \"max_bytes\": 2048\n    }",
  )
}
