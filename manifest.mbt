///|
/// Generate a starter media-pack.json from an existing asset directory. Every
/// regular file gets a path and size budget; supported images also get detected
/// dimensions. The result is a draft for a human to review before `check`.

///|
pub(all) struct ScaffoldResult {
  manifest : String
  generated : Int32
  skipped : Array[String]
}

///|
pub async fn scaffold_manifest(asset_dir : String) -> ScaffoldResult {
  let entries = collect_asset_files(asset_dir)
  let generated_entries : Array[String] = []
  let skipped : Array[String] = []
  for name in entries {
    let path = join_asset_path(asset_dir, name)
    if @fs.kind(path, follow_symlink=false) == @fs.FileKind::Regular {
      let size = @fs.file_size(path)
      if size > 2147483647L {
        skipped.push(name)
      } else {
        let max_bytes = if size > 1073741823L {
          2147483647
        } else if size > 512L {
          Int64::to_int(size) * 2
        } else {
          1024
        }
        let dimensions = match image_format(name) {
          Some(format) => read_image_dimensions(format, path, size)
          None => None
        }
        generated_entries.push(render_asset_entry(name, dimensions, max_bytes))
      }
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
  dimensions : (Int32, Int32)?,
  max_bytes : Int32,
) -> String {
  let dimension_fields = match dimensions {
    Some((width, height)) =>
      "\n      \"width\": \{width},\n      \"height\": \{height},"
    None => ""
  }
  "    {\n      \"file\": \"\{json_escape(file)}\"," +
  dimension_fields +
  "\n      \"max_bytes\": \{max_bytes}\n    }"
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
    render_asset_entry("social/cover.jpeg", Some((1200, 630)), 2048) ==
    "    {\n      \"file\": \"social/cover.jpeg\",\n      \"width\": 1200,\n      \"height\": 630,\n      \"max_bytes\": 2048\n    }",
  )
}

///|
test "renders a generic file entry without image constraints" {
  assert_true(
    render_asset_entry("release-notes.txt", None, 1024) ==
    "    {\n      \"file\": \"release-notes.txt\",\n      \"max_bytes\": 1024\n    }",
  )
}
