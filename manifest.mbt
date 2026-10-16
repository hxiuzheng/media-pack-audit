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
/// Escape a string for inclusion in a JSON string literal, including every
/// control character in U+0000..U+001F.
fn json_escape(value : String) -> String {
  let output = StringBuilder()
  for character in value {
    match character {
      '"' => output <+ "\\\""
      '\\' => output <+ "\\\\"
      '\b' => output <+ "\\b"
      '\u{0C}' => output <+ "\\f"
      '\n' => output <+ "\\n"
      '\r' => output <+ "\\r"
      '\t' => output <+ "\\t"
      _ =>
        if character < ' ' {
          let code = character.to_int()
          output <+ "\\u00"
          output <+ code.to_byte().to_hex()
        } else {
          output <+ "\{character}"
        }
    }
  }
  output.to_string()
}

///|
test "escapes JSON string special characters" {
  assert_eq(json_escape("a\"b\\c"), "a\\\"b\\\\c")
  assert_eq(json_escape("\b\u{0C}\n\r\t"), "\\b\\f\\n\\r\\t")
  assert_eq(json_escape(""), "")
  assert_eq(json_escape("plain"), "plain")
  assert_eq(json_escape(" 中文/🎬\u{7F}"), " 中文/🎬\u{7F}")
}

///|
test "escapes every JSON control character and round-trips strings" {
  let controls = "\u{00}\u{01}\u{02}\u{03}\u{04}\u{05}\u{06}\u{07}\b\t\n\u{0B}\u{0C}\r\u{0E}\u{0F}\u{10}\u{11}\u{12}\u{13}\u{14}\u{15}\u{16}\u{17}\u{18}\u{19}\u{1A}\u{1B}\u{1C}\u{1D}\u{1E}\u{1F}"
  assert_eq(
    json_escape(controls),
    "\\u0000\\u0001\\u0002\\u0003\\u0004\\u0005\\u0006\\u0007\\b\\t\\n\\u000b\\f\\r\\u000e\\u000f\\u0010\\u0011\\u0012\\u0013\\u0014\\u0015\\u0016\\u0017\\u0018\\u0019\\u001a\\u001b\\u001c\\u001d\\u001e\\u001f",
  )
  for character in controls {
    let original = "前\{character}\"\\🎬后"
    let escaped = json_escape(original)
    for output_character in escaped {
      assert_true(output_character >= ' ')
    }
    assert_eq(@json.parse("\"\{escaped}\""), Json::string(original))
  }
  assert_eq(@json.parse("\"\{json_escape(controls)}\""), Json::string(controls))
}

///|
test "rendered manifest preserves escaped filenames and image constraints" {
  // Exercise serialization without creating filenames forbidden on Windows.
  let file = "素材/说明\"\b\u{0C}\n\r\t\u{01}\u{1F}🎬.txt"
  for dimensions in [None, Some((1200, 630))] {
    let entry = render_asset_entry(file, dimensions, 2048)
    let manifest = parse_manifest_json("{\"assets\":[\{entry}]}")
    assert_eq(manifest.assets.length(), 1)
    let asset = manifest.assets[0]
    assert_eq(asset.file, file)
    assert_eq(asset.max_bytes, 2048)
    match dimensions {
      Some((width, height)) => {
        assert_eq(asset.width, Some(width))
        assert_eq(asset.height, Some(height))
      }
      None => {
        assert_eq(asset.width, None)
        assert_eq(asset.height, None)
      }
    }
  }
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
