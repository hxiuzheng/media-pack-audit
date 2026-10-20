///|
// Synthetic structural fixtures intentionally contain four opaque data bytes,
// not a decodable AV1 image. The real hero.avif is exercised by CLI smoke.
fn avif_test_uint(value : Int64, width : Int32) -> Bytes {
  let result : Array[Byte] = []
  for i in 0..<width {
    result.push(
      Int64::to_int((value >> ((width - i - 1) * 8)) & 255L).to_byte(),
    )
  }
  Bytes::from_array(result)
}

///|
fn avif_test_box(tag : Bytes, payload : Bytes) -> Bytes {
  avif_test_uint(Int32::to_int64(payload.length() + 8), 4) + tag + payload
}

///|
fn avif_test_file(
  primary~ : Int64 = 1L,
  declared~ : Int64 = 1L,
  location~ : Int64 = 1L,
  construction~ : Int32 = 0,
  extent_offset~ : Int64 = -1L,
  extent_length~ : Int64 = 4L,
  base~ : Int64 = 0L,
  wide~ : Bool = false,
  split~ : Bool = false,
  external~ : Int64 = 0L,
  pixi~ : Bytes = b"\x03\x08\x08\x08",
  primary_type~ : Bytes = b"av01",
  secondary~ : Bool = false,
  secondary_property~ : Int64 = 1L,
) -> Bytes {
  let zero = b"\x00\x00\x00\x00"
  let id_width = if wide { 4 } else { 2 }
  let number_width = if wide { 8 } else { 4 }
  let ftyp = avif_test_box(b"ftyp", b"avif\x00\x00\x00\x00avif")
  let pitm = avif_test_box(
    b"pitm",
    (if wide { b"\x01\x00\x00\x00" } else { zero }) +
    avif_test_uint(primary, id_width),
  )
  let infe = avif_test_box(
    b"infe",
    (if wide { b"\x03\x00\x00\x00" } else { b"\x02\x00\x00\x00" }) +
    avif_test_uint(declared, id_width) +
    b"\x00\x00" +
    primary_type +
    b"\x00",
  )
  let iinf = avif_test_box(
    b"iinf",
    (if wide { b"\x01\x00\x00\x00" } else { zero }) +
    avif_test_uint(if secondary { 2L } else { 1L }, if wide { 4 } else { 2 }) +
    infe +
    (if secondary {
      avif_test_box(b"infe", b"\x02\x00\x00\x00\x00\x02\x00\x00av01\x00")
    } else {
      b""
    }),
  )
  let ispe = avif_test_box(
    b"ispe",
    zero + avif_test_uint(640L, 4) + avif_test_uint(360L, 4),
  )
  let ipco = avif_test_box(
    b"ipco",
    ispe +
    avif_test_box(b"av1C", b"\x81\x01\x0C\x00") +
    avif_test_box(b"pixi", zero + pixi),
  )
  let ipma = avif_test_box(
    b"ipma",
    (if wide { b"\x01\x00\x00\x01" } else { zero }) +
    avif_test_uint(if secondary { 2L } else { 1L }, 4) +
    avif_test_uint(primary, id_width) +
    b"\x03" +
    (if wide { b"\x00\x01\x80\x02\x00\x03" } else { b"\x01\x82\x03" }) +
    (if secondary {
      avif_test_uint(2L, id_width) +
      b"\x01" +
      avif_test_uint(secondary_property, if wide { 2 } else { 1 })
    } else {
      b""
    }),
  )
  let iprp = avif_test_box(b"iprp", ipco + ipma)
  let version = if wide { 2 } else if construction == 0 { 0 } else { 1 }
  let make_iloc = fn(offset : Int64) {
    let fields = avif_test_uint(location, id_width) +
      (if version == 0 {
        b""
      } else {
        avif_test_uint(Int32::to_int64(construction), 2)
      }) +
      avif_test_uint(external, 2) +
      avif_test_uint(base, number_width) +
      avif_test_uint(if split { 2L } else { 1L }, 2)
    let extents = if split {
      avif_test_uint(offset, number_width) +
      avif_test_uint(2L, number_width) +
      avif_test_uint(offset + 2L, number_width) +
      avif_test_uint(2L, number_width)
    } else {
      avif_test_uint(offset, number_width) +
      avif_test_uint(extent_length, number_width)
    }
    avif_test_box(
      b"iloc",
      avif_test_uint(Int32::to_int64(version), 1) +
      b"\x00\x00\x00" +
      (if wide { b"\x88\x80" } else { b"\x44\x40" }) +
      avif_test_uint(if secondary { 2L } else { 1L }, if wide { 4 } else { 2 }) +
      fields +
      extents +
      (if secondary {
        avif_test_uint(2L, id_width) + fields[id_width:].to_owned() + extents
      } else {
        b""
      }),
    )
  }
  let idat = if construction == 1 {
    avif_test_box(b"idat", b"data")
  } else {
    b""
  }
  let template = avif_test_box(
    b"meta",
    zero + pitm + iinf + iprp + make_iloc(0L) + idat,
  )
  let offset = if extent_offset >= 0L {
    extent_offset
  } else if construction == 1 {
    0L
  } else {
    Int32::to_int64(ftyp.length() + template.length() + 8)
  }
  ftyp +
  avif_test_box(b"meta", zero + pitm + iinf + iprp + make_iloc(offset) + idat) +
  avif_test_box(b"mdat", b"data")
}

///|
fn avif_test_patch(
  bytes : Bytes,
  tag : Bytes,
  relative : Int32,
  value : Bytes,
) -> Bytes {
  let data = bytes.to_array()
  for i in 4..<(bytes.length() - 3) {
    if box_type_is(bytes, i, tag) {
      for j in 0..<value.length() {
        data[i + 4 + relative + j] = value[j]
      }
      return Bytes::from_array(data)
    }
  }
  abort("fixture tag missing")
}

///|
fn avif_test_error(
  bytes : Bytes,
  expected : String,
  item : Int64?,
) -> Unit raise {
  match inspect_avif_structure(bytes, Int32::to_int64(bytes.length())) {
    Err(diagnostic) => {
      assert_eq(diagnostic.code, expected)
      assert_eq(diagnostic.item_id, item)
      assert_true(diagnostic.offset >= 0L)
      assert_true(diagnostic.offset < Int32::to_int64(bytes.length()))
    }
    Ok(_) => fail("expected structural rejection: \{expected}")
  }
}

///|
test "AVIF structure resolves declared primary, properties and mdat extents" {
  let bytes = avif_test_file()
  match inspect_avif_structure(bytes, Int32::to_int64(bytes.length())) {
    Ok(result) => {
      assert_eq(result.primary_item_id, 1L)
      assert_eq(result.width, 640)
      assert_eq(result.height, 360)
      assert_eq(result.item_count, 1)
      assert_eq(result.extents.length(), 1)
      assert_eq(result.extents[0].offset, Int32::to_int64(bytes.length() - 4))
      assert_eq(result.extents[0].length, 4L)
      assert_eq(result.extents[0].storage, "mdat")
    }
    Err(error) => fail(error.detail)
  }
}

///|
test "AVIF structure supports wide IDs and fields, split extents and idat origins" {
  for
    bytes in [
      avif_test_file(
        wide=true,
        primary=70_000L,
        declared=70_000L,
        location=70_000L,
      ),
      avif_test_file(split=true),
      avif_test_file(construction=1),
      avif_test_file(wide=true, construction=1, split=true),
    ] {
    assert_true(
      inspect_avif_structure(bytes, Int32::to_int64(bytes.length())) is Ok(_),
    )
  }
  let bytes = avif_test_file(construction=1)
  match inspect_avif_structure(bytes, Int32::to_int64(bytes.length())) {
    Ok(result) => {
      assert_eq(result.extents[0].storage, "idat")
      let start = Int64::to_int(result.extents[0].offset)
      assert_eq(bytes[start:start + 4].to_owned(), b"data")
    }
    Err(error) => fail(error.detail)
  }
}

///|
test "AVIF old dimension success no longer hides broken declaration or extent" {
  for
    (bytes, code, item) in [
      (avif_test_file(declared=2L), "UNDECLARED_PRIMARY", Some(1L)),
      (avif_test_file(location=2L), "UNDECLARED_ITEM", Some(2L)),
      (avif_test_file(extent_offset=0L), "EXTENT_NOT_IN_MDAT", Some(1L)),
      (avif_test_file(extent_length=5L), "EXTENT_RANGE", Some(1L)),
      (avif_test_file(pixi=b"\x03\x0A\x08\x08"), "PIXI_DEPTH", Some(1L)),
    ] {
    assert_true(avif_dimensions(bytes) == Some((640, 360)))
    avif_test_error(bytes, code, item)
  }
}

///|
test "AVIF validates secondary associations and allows shared media ranges" {
  for wide in [false, true] {
    let bytes = avif_test_file(secondary=true, wide~)
    match inspect_avif_structure(bytes, Int32::to_int64(bytes.length())) {
      Ok(result) => {
        assert_eq(result.item_count, 2)
        assert_eq(result.extents.length(), 2)
        assert_eq(result.extents[0].offset, result.extents[1].offset)
      }
      Err(error) => fail(error.detail)
    }
    let bad = avif_test_file(secondary=true, secondary_property=4L, wide~)
    assert_true(avif_dimensions(bad) == Some((640, 360)))
    avif_test_error(bad, "PROPERTY_INDEX", Some(2L))
  }
  avif_test_error(
    avif_test_file(secondary=true, primary=2L, declared=2L),
    "ITEM_ID",
    Some(2L),
  )
  let two = avif_test_file(secondary=true)
  avif_test_error(
    avif_test_patch(two, b"ipma", 14, b"\x00\x01"),
    "ASSOCIATION_ITEM_ORDER",
    Some(1L),
  )
}

///|
test "AVIF ranges apply base offset and cannot cross the end of mdat into another box" {
  let bytes = avif_test_file()
  let offset = Int32::to_int64(bytes.length() - 4)
  let based = avif_test_file(base=10L, extent_offset=offset - 10L)
  assert_true(
    inspect_avif_structure(based, Int32::to_int64(based.length())) is Ok(_),
  )
  let crossing = avif_test_file(extent_length=5L) +
    avif_test_box(b"free", b"padding")
  avif_test_error(crossing, "EXTENT_NOT_IN_MDAT", Some(1L))
}

///|
test "AVIF rejects dangling properties, missing codec configuration and bad channels" {
  let bytes = avif_test_file()
  avif_test_error(
    avif_test_patch(bytes, b"ipma", 11, b"\x04"),
    "PROPERTY_INDEX",
    Some(1L),
  )
  avif_test_error(
    avif_test_patch(bytes, b"ipma", 12, b"\x00"),
    "MISSING_BOX",
    None,
  )
  avif_test_error(
    avif_test_patch(bytes, b"av1C", 0, b"\x01"),
    "AV1C_HEADER",
    Some(1L),
  )
  avif_test_error(
    avif_test_patch(bytes, b"av1C", 2, b"\x2C"),
    "AV1C_DEPTH",
    Some(1L),
  )
  avif_test_error(avif_test_file(pixi=b"\x01\x08"), "PIXI_CHANNELS", Some(1L))
}

///|
test "AVIF range arithmetic rejects overflow, external references and unsupported layouts" {
  avif_test_error(
    avif_test_file(wide=true, base=9_223_372_036_854_775_807L),
    "EXTENT_RANGE",
    Some(1L),
  )
  avif_test_error(
    avif_test_file(wide=true, base=-1L),
    "UNSUPPORTED_UINT64",
    None,
  )
  avif_test_error(
    avif_test_file(external=1L),
    "UNSUPPORTED_EXTERNAL_DATA",
    Some(1L),
  )
  avif_test_error(
    avif_test_file(construction=2),
    "UNSUPPORTED_CONSTRUCTION",
    Some(1L),
  )
  avif_test_error(
    avif_test_file(extent_length=0L),
    "UNSUPPORTED_IMPLICIT_LENGTH",
    Some(1L),
  )
  avif_test_error(
    avif_test_file(primary_type=b"grid"),
    "UNSUPPORTED_PRIMARY_TYPE",
    Some(1L),
  )
  let idat = avif_test_file(construction=1)
  avif_test_error(
    avif_test_patch(idat, b"iloc", 20, avif_test_uint(1L, 4)),
    "EXTENT_RANGE",
    Some(1L),
  )
}

///|
test "AVIF bounded prefix skips a large final mdat and rejects unseen metadata" {
  let bytes = avif_test_file()
  let large = avif_test_patch(bytes, b"mdat", -8, avif_test_uint(8_388_608L, 4))
  let size = Int32::to_int64(bytes.length() - 12) + 8_388_608L
  assert_true(inspect_avif_structure(large, size) is Ok(_))
  let missing = bytes[0:20].to_owned()
  assert_true(
    inspect_avif_structure(missing, Int32::to_int64(bytes.length())) is Err(_),
  )
  let too_large = Bytes::make(4_194_305, b'\x00')
  assert_true(
    inspect_avif_structure(too_large, 4_194_305L)
    is Err({ code: "LIMIT_METADATA", .. }),
  )
}

///|
test "AVIF recognizes compatible still brand and distinguishes unsupported sequences" {
  let bytes = avif_test_file()
  let compatible = avif_test_patch(bytes, b"ftyp", 0, b"mif1")
  assert_true(
    inspect_avif_structure(compatible, Int32::to_int64(compatible.length()))
    is Ok(_),
  )
  let sequence = avif_test_patch(compatible, b"ftyp", 8, b"avis")
  avif_test_error(sequence, "UNSUPPORTED_BRAND", None)
  let idat = avif_test_file(construction=1)
  let without_mdat = idat[0:idat.length() - 12].to_owned()
  assert_true(
    inspect_avif_structure(without_mdat, Int32::to_int64(without_mdat.length()))
    is Ok(_),
  )
}

///|
test "AVIF fields are constrained to their box and unsigned largesize is bounded" {
  let bytes = avif_test_file()
  avif_test_error(
    avif_test_patch(bytes, b"iloc", 4, b"\x24"),
    "UNSUPPORTED_ILOC_WIDTH",
    None,
  )
  avif_test_error(
    avif_test_patch(bytes, b"iloc", 0, b"\x03"),
    "UNSUPPORTED_ILOC",
    None,
  )
  avif_test_error(
    avif_test_patch(bytes, b"ipma", 4, avif_test_uint(2L, 4)),
    "TRUNCATED_FIELD",
    None,
  )
  avif_test_error(
    avif_test_patch(bytes, b"infe", 12, b"A"),
    "ITEM_NAME",
    Some(1L),
  )
  let oversized = b"\x00\x00\x00\x01ftyp\x80\x00\x00\x00\x00\x00\x00\x00"
  avif_test_error(oversized, "UNSUPPORTED_UINT64", None)
  let too_small = b"\x00\x00\x00\x07ftyp"
  avif_test_error(too_small, "BOX_RANGE", None)
}

///|
test "AVIF count and box budgets reject excessive work before traversing payloads" {
  let bytes = avif_test_file()
  avif_test_error(
    avif_test_patch(bytes, b"iinf", 4, avif_test_uint(257L, 2)),
    "LIMIT_ITEMS",
    None,
  )
  avif_test_error(
    avif_test_patch(bytes, b"iinf", 4, avif_test_uint(2L, 2)),
    "ITEM_COUNT",
    None,
  )
  avif_test_error(
    avif_test_patch(bytes, b"iloc", 16, avif_test_uint(4097L, 2)),
    "LIMIT_EXTENTS",
    Some(1L),
  )
  let mut boxes = b""
  for _ in 0..<4097 {
    boxes = boxes + avif_test_box(b"free", b"")
  }
  avif_test_error(boxes, "LIMIT_BOXES", None)
}

///|
test "AVIF every truncated prefix fails safely and full input succeeds" {
  let bytes = avif_test_file(wide=true, split=true)
  for length in 0..<bytes.length() {
    let truncated = bytes[0:length].to_owned()
    // Treat each truncated prefix as the whole truncated file.
    assert_true(
      inspect_avif_structure(truncated, Int32::to_int64(length)) is Err(_),
    )
  }
  assert_true(
    inspect_avif_structure(bytes, Int32::to_int64(bytes.length())) is Ok(_),
  )
}
