///|
async test "public AVIF structure APIs reject a broken extent despite readable dimensions" {
  let original = @fs.read_file("examples/formats/assets/hero.avif").binary()
  match
    @audit.inspect_avif_structure(original, Int32::to_int64(original.length())) {
    Ok(result) => assert_eq(result.extents[0].offset, 275L)
    Err(error) => fail(error.detail)
  }
  let data = original.to_array()
  data[116] = b'\x00'
  let broken = Bytes::from_array(data)
  assert_true(@audit.avif_dimensions(broken) == Some((640, 360)))
  match
    @audit.inspect_avif_structure(broken, Int32::to_int64(broken.length())) {
    Err(error) => {
      assert_eq(error.code, "EXTENT_NOT_IN_MDAT")
      assert_eq(error.offset, 113L)
      assert_eq(error.item_id, Some(1L))
      assert_eq(error.box_type, "iloc")
    }
    Ok(_) => fail("broken extent should fail across the public API")
  }
  assert_true(
    @audit.inspect_avif_file("_build/absent-avif-structure-file.avif")
    is Err({ code: "IO_ERROR", .. }),
  )
}

///|
/// Controlled fixtures exercise the public API without JSON decoding first.
async test "direct library specs reject invalid constraints in both reports" {
  let asset_dir = "_build/library-spec-invalid"
  if !@fs.exists(asset_dir) {
    @fs.mkdir(asset_dir, recursive=true)
  }
  @fs.write_file(
    "\{asset_dir}/icon.svg",
    "<svg width=\"4\" height=\"3\"></svg>",
  )
  let base : @audit.AssetSpec = {
    file: "icon.svg",
    label: Some("API <constraint>"),
    width: None,
    height: None,
    max_bytes: 1024,
    min_bytes: None,
    expected_sha256: None,
    aspect: None,
    format: None,
  }
  let cases = [
    ({ ..base, min_bytes: Some(0), }, "min_bytes 必须为正整数"),
    ({ ..base, min_bytes: Some(-1), }, "min_bytes 必须为正整数"),
    ({ ..base, min_bytes: Some(1025), }, "min_bytes 不能大于 max_bytes"),
    ({ ..base, format: Some("svgg"), }, "format 必须是受支持的格式名"),
    (
      { ..base, aspect: Some("4:0"), },
      "aspect 必须是 W:H 形式的正整数比例",
    ),
    (
      { ..base, expected_sha256: Some("abc"), },
      "expected_sha256 必须是 64 位十六进制字符串",
    ),
    (
      {
        ..base,
        expected_sha256: Some(
          "gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg",
        ),
      },
      "expected_sha256 必须是 64 位十六进制字符串",
    ),
    ({ ..base, max_bytes: 0, }, "max_bytes 必须为正整数"),
    (
      { ..base, width: Some(4), },
      "width 和 height 必须同时省略或同时为正整数",
    ),
    (
      { ..base, width: Some(0), height: Some(3), },
      "width 和 height 必须同时省略或同时为正整数",
    ),
  ]
  for (spec, expected_error) in cases {
    let manifest : @audit.Manifest = { assets: [spec], max_total_bytes: None, }
    let report = @audit.scan_assets(asset_dir, manifest, "controlled-api-test")
    assert_eq(report.checked, 1)
    assert_eq(report.passed, 0)
    assert_eq(report.failed, 1)
    let result = report.results[0]
    assert_eq(result.status, "FAIL")
    assert_eq(result.file, "icon.svg")
    assert_eq(result.label, base.label)
    assert_eq(result.sha256, "—")
    assert_true(result.details.contains(expected_error))
    assert_true(@json.to_json(report).stringify().contains(expected_error))
    let html = @audit.render_html(report)
    assert_true(html.contains(expected_error))
    assert_true(html.contains("API &lt;constraint&gt;"))
    try @audit.parse_manifest_json(@json.to_json(manifest).stringify()) catch {
      @audit.ManifestParseError::InvalidField(_) => ()
      _ => fail("unexpected error variant")
    } noraise {
      _ => fail("JSON decoding must also reject the invalid constraint")
    }
  }
}

///|
async test "valid direct specs preserve generic files and image constraints" {
  let asset_dir = "_build/library-spec-valid"
  if !@fs.exists(asset_dir) {
    @fs.mkdir(asset_dir, recursive=true)
  }
  let svg = "<svg width=\"4\" height=\"3\"></svg>"
  @fs.write_file("\{asset_dir}/icon.svg", svg)
  @fs.write_file("\{asset_dir}/notes.txt", "abc")
  let notes : @audit.AssetSpec = {
    file: "notes.txt",
    label: None,
    width: None,
    height: None,
    max_bytes: 3,
    min_bytes: Some(3),
    expected_sha256: Some(
      "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD",
    ),
    aspect: None,
    format: None,
  }
  let icon : @audit.AssetSpec = {
    ..notes,
    file: "icon.svg",
    width: Some(4),
    height: Some(3),
    max_bytes: 1024,
    expected_sha256: None,
    aspect: Some("4:3"),
    format: Some("SVG"),
  }
  let manifest : @audit.Manifest = {
    assets: [notes, icon],
    max_total_bytes: None,
  }
  let report = @audit.scan_assets(asset_dir, manifest, "controlled-api-test")
  assert_eq(report.checked, 2)
  assert_eq(report.passed, 2)
  assert_eq(report.failed, 0)
  assert_eq(report.results[0].sha256, @audit.sha256_bytes(b"abc"))
}

///|
test "JSON parser rejects contradictory byte bounds with asset context" {
  let text = "{\"assets\":[{\"file\":\"notes.txt\",\"max_bytes\":3,\"min_bytes\":4}]}"
  try @audit.parse_manifest_json(text) catch {
    @audit.ManifestParseError::InvalidField(message) => {
      assert_true(message.contains("assets[0]"))
      assert_true(message.contains("min_bytes 不能大于 max_bytes"))
    }
    _ => fail("unexpected error variant")
  } noraise {
    _ => fail("contradictory byte bounds must not be accepted")
  }
}
