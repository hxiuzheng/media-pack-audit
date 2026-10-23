///|
struct BindingEvidence {
  index : Int32
  box_type : String
  offset : Int64
  essential : Bool
  interpreted : Bool
} derive(ToJson)

///|
struct ExtentEvidence {
  item_id : Int64
  offset : Int64
  length : Int64
  storage : String
} derive(ToJson)

///|
struct StructureEvidence {
  primary_item_id : Int64
  width : Int32
  height : Int32
  item_count : Int32
  primary_properties : Array[BindingEvidence]
  extents : Array[ExtentEvidence]
} derive(ToJson)

///|
struct DiagnosticEvidence {
  code : String
  box_type : String
  offset : Int64
  item_id : Int64?
  detail : String
} derive(ToJson)

///|
struct CaseEvidence {
  case_id : String
  change : String
  expected : String
  outcome : String
  dimensions_only : String
  structure : StructureEvidence?
  diagnostic : DiagnosticEvidence?
} derive(ToJson)

///|
struct CoreEvidence {
  scope : String
  fixture : String
  case_count : Int32
  cases : Array[CaseEvidence]
} derive(ToJson)

///|
fn evaluate_case(
  case_id : String,
  change : String,
  prefix : Bytes,
  file_size : Int64,
  expected : String,
  expected_offset : Int64?,
  readable_dimensions : Bool,
) -> CaseEvidence raise {
  let dimensions = @audit.avif_dimensions(prefix)
  if readable_dimensions {
    assert_true(dimensions == Some((640, 360)))
  } else {
    assert_true(dimensions is None)
  }
  let dimensions_only = if readable_dimensions {
    "640x360"
  } else {
    "unavailable"
  }
  match @audit.inspect_avif_structure(prefix, file_size) {
    Ok(result) => {
      assert_eq(expected, "supported_subset")
      assert_eq(result.primary_item_id, 1L)
      assert_eq(result.item_count, 1)
      assert_eq(result.width, 640)
      assert_eq(result.height, 360)
      assert_eq(result.extents.length(), 1)
      assert_eq(result.extents[0].offset, 275L)
      assert_eq(result.extents[0].length, 83L)
      assert_eq(result.primary_properties.length(), 4)
      assert_eq(result.primary_properties[0].index, 1)
      assert_eq(result.primary_properties[0].box_type, "ispe")
      assert_eq(result.primary_properties[2].box_type, "av1C")
      assert_true(result.primary_properties[2].essential)
      assert_true(result.primary_properties[2].interpreted)
      assert_true(!result.primary_properties[3].essential)
      assert_true(!result.primary_properties[3].interpreted)
      assert_eq(
        result.primary_properties[3].box_type,
        if case_id == "unknown-nonessential" {
          "zzzz"
        } else {
          "colr"
        },
      )
      let properties : Array[BindingEvidence] = []
      for binding in result.primary_properties {
        properties.push({
          index: binding.index,
          box_type: binding.box_type,
          offset: binding.offset,
          essential: binding.essential,
          interpreted: binding.interpreted,
        })
      }
      let extents : Array[ExtentEvidence] = []
      for extent in result.extents {
        extents.push({
          item_id: extent.item_id,
          offset: extent.offset,
          length: extent.length,
          storage: extent.storage,
        })
      }
      {
        case_id,
        change,
        expected,
        outcome: "supported_subset",
        dimensions_only,
        structure: Some({
          primary_item_id: result.primary_item_id,
          width: result.width,
          height: result.height,
          item_count: result.item_count,
          primary_properties: properties,
          extents,
        }),
        diagnostic: None,
      }
    }
    Err(error) => {
      assert_eq(error.code, expected)
      match expected_offset {
        Some(offset) => {
          assert_eq(error.offset, offset)
          assert_eq(error.item_id, Some(1L))
        }
        None => ()
      }
      {
        case_id,
        change,
        expected,
        outcome: if error.code.has_prefix("UNSUPPORTED_") {
          "unsupported"
        } else if error.code.has_prefix("LIMIT_") {
          "incomplete"
        } else {
          "structural_error"
        },
        dimensions_only,
        structure: None,
        diagnostic: Some({
          code: error.code,
          box_type: error.box_type,
          offset: error.offset,
          item_id: error.item_id,
          detail: error.detail,
        }),
      }
    }
  }
}

///|
/// A core-only consumer: no external manifest, expected hash, package scan or
/// HTML report. Mutations stay in memory and never change the source image.
async fn main {
  let output_dir = "_build/avif-semantics"
  if @fs.exists(output_dir) {
    if @fs.kind(output_dir, follow_symlink=false) != @fs.FileKind::Directory {
      raise Failure::Failure(
        "core evidence output must be an ordinary directory",
      )
    }
  } else {
    @fs.mkdir(output_dir, recursive=true)
  }
  let output = "\{output_dir}/evidence.json"
  if @fs.exists(output) {
    if @fs.kind(output, follow_symlink=false) != @fs.FileKind::Regular {
      raise Failure::Failure("core evidence output must be an ordinary file")
    }
    @fs.remove(output)
  }
  let fixture = "examples/formats/assets/hero.avif"
  let original = @fs.read_file(fixture).binary()
  let file_size = Int32::to_int64(original.length())
  match @audit.inspect_avif_file(fixture) {
    Ok(result) => {
      assert_eq(result.primary_item_id, 1L)
      assert_eq(result.extents[0].offset, 275L)
      assert_eq(result.primary_properties[2].box_type, "av1C")
    }
    Err(error) => raise Failure::Failure(error.detail)
  }
  let cases : Array[CaseEvidence] = []
  for
    (name, change, offset, byte, expected, location, readable) in [
      (
        "direct-primary",
        "unchanged real AVIF",
        0,
        original[0],
        "supported_subset",
        None,
        true,
      ),
      (
        "undeclared-primary",
        "infe item ID 1 -> 2",
        148,
        b'\x02',
        "UNDECLARED_PRIMARY",
        Some(89L),
        true,
      ),
      (
        "extent-outside-media",
        "iloc extent points into metadata",
        116,
        b'\x00',
        "EXTENT_NOT_IN_MDAT",
        Some(113L),
        true,
      ),
      (
        "dangling-property",
        "ipma index exceeds ipco",
        263,
        b'\x7F',
        "PROPERTY_INDEX",
        Some(263L),
        false,
      ),
      (
        "depth-conflict",
        "pixi first depth 8 -> 10, av1C stays 8",
        210,
        b'\x0A',
        "PIXI_DEPTH",
        Some(210L),
        true,
      ),
      (
        "unknown-nonessential",
        "rename nonessential colr to zzzz",
        0,
        original[0],
        "supported_subset",
        None,
        true,
      ),
      (
        "unimplemented-essential",
        "mark unhandled colr essential",
        266,
        b'\x84',
        "UNSUPPORTED_ESSENTIAL_PROPERTY",
        Some(266L),
        true,
      ),
    ] {
    let data = original.to_array()
    data[offset] = byte
    if name == "unknown-nonessential" {
      for i in 229..<233 {
        data[i] = b'z'
      }
    }
    cases.push(
      evaluate_case(
        name,
        change,
        Bytes::from_array(data),
        file_size,
        expected,
        location,
        readable,
      ),
    )
  }
  let no_essential_target = original.to_array()
  no_essential_target[263] = b'\x80'
  cases.push(
    evaluate_case(
      "essential-zero-index",
      "set primary ispe association index to zero but keep essential set",
      Bytes::from_array(no_essential_target),
      file_size,
      "PROPERTY_ESSENTIAL_ZERO",
      Some(263L),
      false,
    ),
  )
  cases.push(
    evaluate_case(
      "prefix-limit",
      "provide only 200 bytes of a complete 358-byte file",
      original[:200].to_owned(),
      file_size,
      "LIMIT_METADATA",
      None,
      false,
    ),
  )
  let evidence : CoreEvidence = {
    scope: "bounded direct-static-AVIF metadata relationships; no AV1 pixel decoding",
    fixture,
    case_count: cases.length(),
    cases,
  }
  @fs.write_file(output, @json.to_json(evidence).stringify(indent=2))
  for result in cases {
    println(
      "\{result.case_id}: \{result.outcome} / \{result.expected}; dimensions-only=\{result.dimensions_only}",
    )
  }
  println("AVIF semantic evidence: \{cases.length()} asserted cases; \{output}")
}
