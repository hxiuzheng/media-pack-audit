///|
/// A structural fault or an explicit limit of the supported AVIF profile.
/// offset is an absolute byte offset in the original file. Codes beginning
/// UNSUPPORTED_ or LIMIT_ do not assert that the input violates AVIF.
pub(all) struct AvifDiagnostic {
  code : String
  box_type : String
  offset : Int64
  item_id : Int64?
  detail : String
} derive(Debug)

///|
pub extend AvifDiagnostic with Debug::{to_repr}

///|
/// A resolved, nonempty item extent contained in one mdat or idat payload.
/// Shared ranges between different items are permitted.
pub(all) struct AvifExtent {
  item_id : Int64
  offset : Int64
  length : Int64
  storage : String
} derive(Debug)

///|
pub extend AvifExtent with Debug::{to_repr}

///|
/// One primary-item binding, in ipma association order. index is the original
/// one-based ipco index; offset locates the property's box header in the file.
/// interpreted means only the documented ispe/av1C/pixi field subset was checked,
/// not that the complete property semantics or AV1 payload were validated.
pub(all) struct AvifPropertyAssociation {
  index : Int32
  box_type : String
  offset : Int64
  essential : Bool
  interpreted : Bool
} derive(Debug)

///|
pub extend AvifPropertyAssociation with Debug::{to_repr}

///|
/// Successful validation of the documented structural subset, not AV1 decoding
/// or full AVIF conformance. Dimensions are the primary item's stored ispe.
pub(all) struct AvifStructure {
  primary_item_id : Int64
  width : Int32
  height : Int32
  item_count : Int32
  primary_properties : Array[AvifPropertyAssociation]
  extents : Array[AvifExtent]
} derive(Debug)

///|
pub extend AvifStructure with Debug::{to_repr}

///|
priv suberror AvifStructureFailure {
  AvifFault(AvifDiagnostic)
}

///|
priv struct AvifNode {
  kind : String
  header : Int64
  payload : Int64
  end : Int64
}

///|
priv struct AvifBudget {
  mut boxes : Int32
  mut associations : Int32
  mut extents : Int32
}

///|
priv struct AvifBinding {
  index : Int32
  offset : Int64
  essential : Bool
}

///|
priv struct AvifCursor {
  bytes : Bytes
  mut position : Int32
  end : Int32
  kind : String
  item : Int64?
}

///|
fn[T] avif_fault(
  code : String,
  kind : String,
  offset : Int64,
  item : Int64?,
  detail : String,
) -> T raise AvifStructureFailure {
  raise AvifStructureFailure::AvifFault({
    code,
    box_type: kind,
    offset,
    item_id: item,
    detail,
  })
}

///|
fn avif_need(
  condition : Bool,
  code : String,
  kind : String,
  offset : Int64,
  item : Int64?,
  detail : String,
) -> Unit raise AvifStructureFailure {
  if !condition {
    avif_fault(code, kind, offset, item, detail)
  }
}

///|
fn AvifCursor::uint(
  self : AvifCursor,
  width : Int32,
) -> Int64 raise AvifStructureFailure {
  let offset = Int32::to_int64(self.position)
  avif_need(
    width >= 0 && width <= 8 && width <= self.end - self.position,
    "TRUNCATED_FIELD",
    self.kind,
    offset,
    self.item,
    "字段超出所属盒边界",
  )
  if width == 8 {
    avif_need(
      self.bytes[self.position].to_int() < 128,
      "UNSUPPORTED_UINT64",
      self.kind,
      offset,
      self.item,
      "无符号 64 位值超过本实现的 Int64 范围",
    )
  }
  let mut value = 0L
  for _ in 0..<width {
    value = value * 256L + Int32::to_int64(self.bytes[self.position].to_int())
    self.position += 1
  }
  value
}

///|
fn AvifCursor::finish(self : AvifCursor) -> Unit raise AvifStructureFailure {
  avif_need(
    self.position == self.end,
    "TRAILING_FIELDS",
    self.kind,
    Int32::to_int64(self.position),
    self.item,
    "盒内存在未消费的字段或计数字段不匹配",
  )
}

///|
fn AvifCursor::fullbox(
  self : AvifCursor,
) -> (Int32, Int64) raise AvifStructureFailure {
  let version = Int64::to_int(self.uint(1))
  let flags = self.uint(3)
  (version, flags)
}

///|
fn avif_node_kind(bytes : Bytes, offset : Int32) -> String {
  for
    (tag, name) in [
      (b"ftyp", "ftyp"),
      (b"meta", "meta"),
      (b"mdat", "mdat"),
      (b"idat", "idat"),
      (b"pitm", "pitm"),
      (b"iinf", "iinf"),
      (b"infe", "infe"),
      (b"iloc", "iloc"),
      (b"iprp", "iprp"),
      (b"ipco", "ipco"),
      (b"ipma", "ipma"),
      (b"ispe", "ispe"),
      (b"av1C", "av1C"),
      (b"pixi", "pixi"),
      (b"av01", "av01"),
      (b"Exif", "Exif"),
      (b"mime", "mime"),
      (b"grid", "grid"),
      (b"uuid", "uuid"),
      (b"free", "free"),
      (b"skip", "skip"),
    ] {
    if box_type_is(bytes, offset, tag) {
      return name
    }
  }
  let name = StringBuilder()
  for i in 0..<4 {
    name.write_char(bytes[offset + i].to_char())
  }
  name.to_string()
}

///|
fn avif_cursor(
  bytes : Bytes,
  node : AvifNode,
  item : Int64?,
) -> AvifCursor raise AvifStructureFailure {
  avif_need(
    node.end <= Int32::to_int64(bytes.length()),
    "LIMIT_METADATA",
    node.kind,
    node.header,
    item,
    "所需元数据不完整地位于提供的前缀中（上限 4 MiB）",
  )
  {
    bytes,
    position: Int64::to_int(node.payload),
    end: Int64::to_int(node.end),
    kind: node.kind,
    item,
  }
}

///|
/// All arithmetic is checked against the enclosing range before addition.
/// A last mdat can extend beyond the supplied prefix without being read.
fn avif_nodes(
  bytes : Bytes,
  start : Int64,
  end : Int64,
  budget : AvifBudget,
  top_level~ : Bool = false,
) -> Array[AvifNode] raise AvifStructureFailure {
  let nodes : Array[AvifNode] = []
  let mut position = start
  while position < end {
    avif_need(
      budget.boxes < 4096,
      "LIMIT_BOXES",
      "container",
      position,
      None,
      "所访问的盒总数超过 4096",
    )
    budget.boxes += 1
    avif_need(
      end - position >= 8,
      "TRUNCATED_BOX",
      "container",
      position,
      None,
      "剩余空间不足一个盒头",
    )
    avif_need(
      position <= Int32::to_int64(bytes.length()) - 8L,
      "LIMIT_METADATA",
      "container",
      position,
      None,
      "盒头超出提供的元数据前缀",
    )
    let index = Int64::to_int(position)
    let kind = avif_node_kind(bytes, index + 4)
    let mut header_size = 8L
    let size32 = be_u32(bytes, index)
    let size = if size32 == 0L {
      avif_need(
        top_level,
        "BOX_SIZE_ZERO",
        kind,
        position,
        None,
        "size=0 只能用于延伸至文件末尾的顶层盒",
      )
      end - position
    } else if size32 == 1L {
      avif_need(
        end - position >= 16L &&
        position <= Int32::to_int64(bytes.length()) - 16L,
        "TRUNCATED_BOX",
        kind,
        position,
        None,
        "扩展盒头不完整",
      )
      avif_need(
        bytes[index + 8].to_int() < 128,
        "UNSUPPORTED_UINT64",
        kind,
        position + 8L,
        None,
        "扩展盒大小超过 Int64 范围",
      )
      header_size = 16L
      be_u64(bytes, index + 8)
    } else {
      size32
    }
    if kind == "uuid" {
      header_size += 16L
    }
    avif_need(
      size >= header_size && size <= end - position,
      "BOX_RANGE",
      kind,
      position,
      None,
      "声明盒大小超出所属容器",
    )
    avif_need(
      position <= Int32::to_int64(bytes.length()) - header_size,
      "LIMIT_METADATA",
      kind,
      position,
      None,
      "完整盒头（含 UUID user type）必须位于提供的元数据前缀中",
    )
    nodes.push({
      kind,
      header: position,
      payload: position + header_size,
      end: position + size,
    })
    position += size
  }
  nodes
}

///|
fn avif_optional_node(
  nodes : Array[AvifNode],
  kind : String,
) -> AvifNode? raise AvifStructureFailure {
  let mut found = None
  for node in nodes {
    if node.kind == kind {
      avif_need(
        found is None,
        "DUPLICATE_BOX",
        kind,
        node.header,
        None,
        "唯一盒出现多次",
      )
      found = Some(node)
    }
  }
  found
}

///|
fn avif_required_node(
  nodes : Array[AvifNode],
  kind : String,
  parent : AvifNode,
) -> AvifNode raise AvifStructureFailure {
  match avif_optional_node(nodes, kind) {
    Some(node) => node
    None =>
      avif_fault(
        "MISSING_BOX",
        kind,
        parent.payload,
        None,
        "缺少必需的结构盒",
      )
  }
}

///|
fn avif_item_types(
  bytes : Bytes,
  node : AvifNode,
  budget : AvifBudget,
) -> Map[Int64, String] raise AvifStructureFailure {
  let cursor = avif_cursor(bytes, node, None)
  let (version, flags) = cursor.fullbox()
  avif_need(
    version <= 1 && flags == 0L,
    "UNSUPPORTED_IINF",
    "iinf",
    node.payload,
    None,
    "仅支持版本 0/1 且 flags 为零的 iinf",
  )
  let count = cursor.uint(if version == 0 { 2 } else { 4 })
  avif_need(
    count > 0L && count <= 256L,
    "LIMIT_ITEMS",
    "iinf",
    node.payload,
    None,
    "声明 item 数量必须在 1–256 范围",
  )
  let children = avif_nodes(
    bytes,
    Int32::to_int64(cursor.position),
    node.end,
    budget,
  )
  let entries : Array[AvifNode] = []
  for entry in children {
    if entry.kind != "free" && entry.kind != "skip" {
      entries.push(entry)
    }
  }
  avif_need(
    Int32::to_int64(entries.length()) == count,
    "ITEM_COUNT",
    "iinf",
    node.payload,
    None,
    "entry_count 与实际 infe 数量不一致",
  )
  let items : Map[Int64, String] = Map([])
  for entry in entries {
    avif_need(
      entry.kind == "infe",
      "ITEM_ENTRY",
      "iinf",
      entry.header,
      None,
      "iinf 条目必须为 infe",
    )
    let info = avif_cursor(bytes, entry, None)
    let (info_version, info_flags) = info.fullbox()
    avif_need(
      (info_version == 2 || info_version == 3) && info_flags <= 1L,
      "UNSUPPORTED_INFE",
      "infe",
      entry.payload,
      None,
      "仅支持带 item_type 的 infe 版本 2/3",
    )
    let id_offset = Int32::to_int64(info.position)
    let id = info.uint(if info_version == 2 { 2 } else { 4 })
    avif_need(
      id > 0L && !items.contains(id),
      "ITEM_ID",
      "infe",
      id_offset,
      Some(id),
      "item_ID 为零或重复",
    )
    avif_need(
      info.uint(2) == 0L,
      "UNSUPPORTED_PROTECTION",
      "infe",
      Int32::to_int64(info.position - 2),
      Some(id),
      "不支持受保护的 item",
    )
    let tag_offset = info.position
    ignore(info.uint(4))
    let kind = avif_node_kind(bytes, tag_offset)
    let mut terminated = false
    while info.position < info.end {
      if info.uint(1) == 0L {
        terminated = true
        break
      }
    }
    avif_need(
      terminated,
      "ITEM_NAME",
      "infe",
      entry.payload,
      Some(id),
      "item_name 缺少结尾的零字节",
    )
    // Type-specific MIME/URI suffixes are outside this structural profile.
    if kind == "av01" {
      info.finish()
    }
    items.set(id, kind)
  }
  items
}

///|
fn avif_associations(
  bytes : Bytes,
  nodes : Array[AvifNode],
  properties : Array[AvifNode],
  items : Map[Int64, String],
  budget : AvifBudget,
) -> Map[Int64, Array[AvifBinding]] raise AvifStructureFailure {
  let associations : Map[Int64, Array[AvifBinding]] = Map([])
  let variants : Map[Int32, Bool] = Map([])
  for node in nodes {
    if node.kind == "free" || node.kind == "skip" {
      continue
    }
    avif_need(
      node.kind == "ipco" || node.kind == "ipma",
      "UNSUPPORTED_IPRP_CHILD",
      "iprp",
      node.header,
      None,
      "本子集只处理 ipco、ipma 和填充盒",
    )
    if node.kind != "ipma" {
      continue
    }
    let cursor = avif_cursor(bytes, node, None)
    let (version, flags) = cursor.fullbox()
    avif_need(
      version <= 1 && flags <= 1L,
      "UNSUPPORTED_IPMA",
      "ipma",
      node.payload,
      None,
      "仅支持 ipma 版本 0/1、flags 0/1",
    )
    let variant = version * 2 + Int64::to_int(flags)
    avif_need(
      !variants.contains(variant),
      "DUPLICATE_IPMA",
      "ipma",
      node.payload,
      None,
      "相同 version/flags 的 ipma 出现多次",
    )
    variants.set(variant, true)
    let count = cursor.uint(4)
    avif_need(
      count <= 256L,
      "LIMIT_ITEMS",
      "ipma",
      node.payload,
      None,
      "ipma 条目超过 256",
    )
    let mut previous_id = 0L
    for _ in 0..<Int64::to_int(count) {
      let offset = Int32::to_int64(cursor.position)
      let id = cursor.uint(if version == 0 { 2 } else { 4 })
      avif_need(
        id > previous_id && !associations.contains(id),
        "ASSOCIATION_ITEM_ORDER",
        "ipma",
        offset,
        Some(id),
        "item_ID 必须递增，且在所有 ipma 中唯一",
      )
      previous_id = id
      avif_need(
        items.contains(id),
        "UNDECLARED_ITEM",
        "ipma",
        offset,
        Some(id),
        "属性关联引用了未声明的 item",
      )
      let property_count = Int64::to_int(cursor.uint(1))
      avif_need(
        property_count <= 4096 - budget.associations,
        "LIMIT_ASSOCIATIONS",
        "ipma",
        offset,
        Some(id),
        "属性关联总数超过 4096",
      )
      budget.associations += property_count
      let bindings : Array[AvifBinding] = []
      for _ in 0..<property_count {
        let property_offset = Int32::to_int64(cursor.position)
        let raw = cursor.uint(if flags == 0L { 1 } else { 2 })
        let index = Int64::to_int(
          raw & (if flags == 0L { 0x7FL } else { 0x7FFFL }),
        )
        let essential = (raw & (if flags == 0L { 0x80L } else { 0x8000L })) !=
          0L
        // ISO/IEC 14496-12 8.11.14.3: a zero property index denotes no
        // association, so its essential bit must also be zero.
        avif_need(
          index != 0 || !essential,
          "PROPERTY_ESSENTIAL_ZERO",
          "ipma",
          property_offset,
          Some(id),
          "property_index 为零时 essential 必须为零",
        )
        avif_need(
          index <= properties.length(),
          "PROPERTY_INDEX",
          "ipma",
          property_offset,
          Some(id),
          "属性索引越过 ipco 属性列表",
        )
        if index > 0 {
          bindings.push({ index, offset: property_offset, essential, })
        }
      }
      associations.set(id, bindings)
    }
    cursor.finish()
  }
  associations
}

///|
fn avif_location_width(
  width : Int32,
  node : AvifNode,
) -> Unit raise AvifStructureFailure {
  avif_need(
    width == 0 || width == 4 || width == 8,
    "UNSUPPORTED_ILOC_WIDTH",
    "iloc",
    node.payload,
    None,
    "iloc offset/length/base/index 字段仅支持 0、4、8 字节",
  )
}

///|
fn avif_locations(
  bytes : Bytes,
  node : AvifNode,
  items : Map[Int64, String],
  primary : Int64,
  media : Array[AvifNode],
  idat : AvifNode?,
  file_size : Int64,
  budget : AvifBudget,
) -> Array[AvifExtent] raise AvifStructureFailure {
  let cursor = avif_cursor(bytes, node, None)
  let (version, flags) = cursor.fullbox()
  avif_need(
    version <= 2 && flags == 0L,
    "UNSUPPORTED_ILOC",
    "iloc",
    node.payload,
    None,
    "仅支持 iloc 版本 0/1/2 且 flags 为零",
  )
  let sizes = Int64::to_int(cursor.uint(1))
  let base_sizes = Int64::to_int(cursor.uint(1))
  let offset_size = sizes >> 4
  let length_size = sizes & 15
  let base_size = base_sizes >> 4
  let index_size = if version == 0 { 0 } else { base_sizes & 15 }
  avif_location_width(offset_size, node)
  avif_location_width(length_size, node)
  avif_location_width(base_size, node)
  avif_location_width(index_size, node)
  avif_need(
    version != 0 || (base_sizes & 15) == 0,
    "RESERVED_BITS",
    "iloc",
    node.payload + 5L,
    None,
    "iloc 版本 0 的保留位必须为零",
  )
  let count = cursor.uint(if version == 2 { 4 } else { 2 })
  avif_need(
    count <= 256L,
    "LIMIT_ITEMS",
    "iloc",
    node.payload,
    None,
    "iloc 条目超过 256",
  )
  let seen : Map[Int64, Bool] = Map([])
  let extents : Array[AvifExtent] = []
  for _ in 0..<Int64::to_int(count) {
    let item_offset = Int32::to_int64(cursor.position)
    let id = cursor.uint(if version == 2 { 4 } else { 2 })
    avif_need(
      items.contains(id),
      "UNDECLARED_ITEM",
      "iloc",
      item_offset,
      Some(id),
      "数据位置引用了未声明的 item",
    )
    avif_need(
      !seen.contains(id),
      "DUPLICATE_LOCATION",
      "iloc",
      item_offset,
      Some(id),
      "同一 item 的位置条目出现多次",
    )
    seen.set(id, true)
    let method_field = if version == 0 { 0L } else { cursor.uint(2) }
    avif_need(
      (method_field & 0xFFF0L) == 0L,
      "RESERVED_BITS",
      "iloc",
      item_offset,
      Some(id),
      "construction_method 保留位必须为零",
    )
    let construction = method_field & 15L
    avif_need(
      construction <= 1L,
      "UNSUPPORTED_CONSTRUCTION",
      "iloc",
      item_offset,
      Some(id),
      "仅支持文件偏移（0）和 idat 偏移（1）",
    )
    avif_need(
      cursor.uint(2) == 0L,
      "UNSUPPORTED_EXTERNAL_DATA",
      "iloc",
      Int32::to_int64(cursor.position - 2),
      Some(id),
      "仅支持当前文件内的数据引用",
    )
    let base = cursor.uint(base_size)
    let extent_count = Int64::to_int(cursor.uint(2))
    avif_need(
      extent_count > 0,
      "UNSUPPORTED_EMPTY_ITEM",
      "iloc",
      item_offset,
      Some(id),
      "不支持没有显式数据区间的 item",
    )
    avif_need(
      extent_count <= 4096 - budget.extents,
      "LIMIT_EXTENTS",
      "iloc",
      item_offset,
      Some(id),
      "数据区间总数超过 4096",
    )
    budget.extents += extent_count
    let (origin, limit, storage) = if construction == 0L {
      (0L, file_size, "mdat")
    } else {
      match idat {
        Some(data) => (data.payload, data.end - data.payload, "idat")
        None =>
          avif_fault(
            "MISSING_IDAT",
            "iloc",
            item_offset,
            Some(id),
            "construction_method=1 但 meta 中没有 idat",
          )
      }
    }
    for _ in 0..<extent_count {
      let field_offset = Int32::to_int64(cursor.position)
      avif_need(
        cursor.uint(index_size) == 0L,
        "UNSUPPORTED_EXTENT_INDEX",
        "iloc",
        field_offset,
        Some(id),
        "不支持非零 extent_index",
      )
      let offset = cursor.uint(offset_size)
      let length = cursor.uint(length_size)
      avif_need(
        length > 0L,
        "UNSUPPORTED_IMPLICIT_LENGTH",
        "iloc",
        field_offset,
        Some(id),
        "需要显式的正 extent_length",
      )
      avif_need(
        base <= limit && offset <= limit - base,
        "EXTENT_RANGE",
        "iloc",
        field_offset,
        Some(id),
        "base_offset + extent_offset 超出数据来源范围",
      )
      let relative = base + offset
      avif_need(
        length <= limit - relative,
        "EXTENT_RANGE",
        "iloc",
        field_offset,
        Some(id),
        "数据区间尾部超出数据来源范围",
      )
      let absolute = origin + relative
      if construction == 0L {
        let mut contained = false
        for data in media {
          if absolute >= data.payload &&
            absolute <= data.end &&
            length <= data.end - absolute {
            contained = true
            break
          }
        }
        avif_need(
          contained,
          "EXTENT_NOT_IN_MDAT",
          "iloc",
          field_offset,
          Some(id),
          "数据区间不完整地位于一个 mdat 的有效载荷内",
        )
      }
      extents.push({ item_id: id, offset: absolute, length, storage, })
    }
  }
  cursor.finish()
  avif_need(
    seen.contains(primary),
    "MISSING_PRIMARY_LOCATION",
    "iloc",
    node.payload,
    Some(primary),
    "主图没有数据位置条目",
  )
  extents
}

///|
fn avif_primary_properties(
  bytes : Bytes,
  properties : Array[AvifNode],
  bindings : Array[AvifBinding],
  primary : Int64,
  parent : AvifNode,
) -> (Int32, Int32, Array[AvifPropertyAssociation]) raise AvifStructureFailure {
  let selected : Array[AvifNode] = []
  let evidence : Array[AvifPropertyAssociation] = []
  for binding in bindings {
    let property = properties[binding.index - 1]
    let interpreted = property.kind == "ispe" ||
      property.kind == "av1C" ||
      property.kind == "pixi"
    avif_need(
      !binding.essential || interpreted,
      "UNSUPPORTED_ESSENTIAL_PROPERTY",
      "ipma",
      binding.offset,
      Some(primary),
      "主图属性 \{property.kind} 标记为 essential，但不在已解释的属性子集内",
    )
    selected.push(property)
    evidence.push({
      index: binding.index,
      box_type: property.kind,
      offset: property.header,
      essential: binding.essential,
      interpreted,
    })
  }
  let ispe = avif_required_node(selected, "ispe", parent)
  let config = avif_required_node(selected, "av1C", parent)
  let cursor = avif_cursor(bytes, ispe, Some(primary))
  let (version, flags) = cursor.fullbox()
  avif_need(
    version == 0 && flags == 0L,
    "UNSUPPORTED_ISPE",
    "ispe",
    ispe.payload,
    Some(primary),
    "仅支持版本零的 ispe",
  )
  let width = cursor.uint(4)
  let height = cursor.uint(4)
  cursor.finish()
  avif_need(
    width > 0L &&
    height > 0L &&
    width <= 2_147_483_647L &&
    height <= 2_147_483_647L,
    "DIMENSIONS",
    "ispe",
    ispe.payload + 4L,
    Some(primary),
    "尺寸必须为正且在 Int32 范围",
  )
  let codec = avif_cursor(bytes, config, Some(primary))
  avif_need(
    codec.uint(1) == 0x81L,
    "AV1C_HEADER",
    "av1C",
    config.payload,
    Some(primary),
    "av1C marker/version 必须为 0x81",
  )
  ignore(codec.uint(1))
  let coding = codec.uint(1)
  ignore(codec.uint(1))
  let high_depth = (coding & 0x40L) != 0L
  let twelve_bit = (coding & 0x20L) != 0L
  avif_need(
    !twelve_bit || high_depth,
    "AV1C_DEPTH",
    "av1C",
    config.payload + 2L,
    Some(primary),
    "twelve_bit 不能在 high_bitdepth 为零时设置",
  )
  let depth = if twelve_bit { 12L } else if high_depth { 10L } else { 8L }
  let channels = if (coding & 0x10L) != 0L { 1L } else { 3L }
  match avif_optional_node(selected, "pixi") {
    Some(pixi) => {
      let pixels = avif_cursor(bytes, pixi, Some(primary))
      let (pixel_version, pixel_flags) = pixels.fullbox()
      avif_need(
        pixel_version == 0 && pixel_flags == 0L,
        "UNSUPPORTED_PIXI",
        "pixi",
        pixi.payload,
        Some(primary),
        "仅支持版本零的 pixi",
      )
      avif_need(
        pixels.uint(1) == channels,
        "PIXI_CHANNELS",
        "pixi",
        pixi.payload + 4L,
        Some(primary),
        "pixi 通道数与 av1C 不一致",
      )
      for _ in 0..<Int64::to_int(channels) {
        let offset = Int32::to_int64(pixels.position)
        avif_need(
          pixels.uint(1) == depth,
          "PIXI_DEPTH",
          "pixi",
          offset,
          Some(primary),
          "pixi 位深与 av1C 不一致",
        )
      }
      pixels.finish()
    }
    None => ()
  }
  (Int64::to_int(width), Int64::to_int(height), evidence)
}

///|
fn avif_inspect(
  prefix : Bytes,
  file_size : Int64,
) -> AvifStructure raise AvifStructureFailure {
  avif_need(
    file_size >= Int32::to_int64(prefix.length()) &&
    prefix.length() <= 4_194_304,
    "LIMIT_METADATA",
    "file",
    0L,
    None,
    "前缀必须不超过文件大小及 4 MiB 上限",
  )
  let budget : AvifBudget = { boxes: 0, associations: 0, extents: 0, }
  let root : AvifNode = {
    kind: "file",
    header: 0L,
    payload: 0L,
    end: file_size,
  }
  let top = avif_nodes(prefix, 0L, file_size, budget, top_level=true)
  avif_need(
    top.length() > 0 && top[0].kind == "ftyp",
    "MISSING_FTYP",
    "file",
    0L,
    None,
    "首盒必须为 ftyp",
  )
  let ftyp = avif_required_node(top, "ftyp", root)
  avif_need(
    ftyp.end - ftyp.payload >= 8L && (ftyp.end - ftyp.payload - 8L) % 4L == 0L,
    "FTYP_FIELDS",
    "ftyp",
    ftyp.payload,
    None,
    "品牌盒必须含主品牌、版本及完整的兼容品牌字段",
  )
  ignore(avif_cursor(prefix, ftyp, None))
  let mut still_brand = box_type_is(
    prefix,
    Int64::to_int(ftyp.payload),
    b"avif",
  )
  let mut brand_offset = ftyp.payload + 8L
  while brand_offset < ftyp.end {
    if box_type_is(prefix, Int64::to_int(brand_offset), b"avif") {
      still_brand = true
    }
    brand_offset += 4L
  }
  avif_need(
    still_brand,
    "UNSUPPORTED_BRAND",
    "ftyp",
    ftyp.payload,
    None,
    "需要主品牌或兼容品牌 avif；仅有 avis 的序列不在本结构子集内",
  )
  let meta = avif_required_node(top, "meta", root)
  let cursor = avif_cursor(prefix, meta, None)
  let (version, flags) = cursor.fullbox()
  avif_need(
    version == 0 && flags == 0L,
    "UNSUPPORTED_META",
    "meta",
    meta.payload,
    None,
    "仅支持版本零的 meta",
  )
  let children = avif_nodes(
    prefix,
    Int32::to_int64(cursor.position),
    meta.end,
    budget,
  )
  let pitm = avif_required_node(children, "pitm", meta)
  let primary_reader = avif_cursor(prefix, pitm, None)
  let (primary_version, primary_flags) = primary_reader.fullbox()
  avif_need(
    primary_version <= 1 && primary_flags == 0L,
    "UNSUPPORTED_PITM",
    "pitm",
    pitm.payload,
    None,
    "仅支持 pitm 版本 0/1",
  )
  let primary = primary_reader.uint(if primary_version == 0 { 2 } else { 4 })
  primary_reader.finish()
  let items = avif_item_types(
    prefix,
    avif_required_node(children, "iinf", meta),
    budget,
  )
  avif_need(
    items.contains(primary),
    "UNDECLARED_PRIMARY",
    "pitm",
    pitm.payload + 4L,
    Some(primary),
    "主图 item 未在 iinf 中声明",
  )
  avif_need(
    items.get(primary) == Some("av01"),
    "UNSUPPORTED_PRIMARY_TYPE",
    "pitm",
    pitm.payload + 4L,
    Some(primary),
    "当前结构子集只支持直接 av01 主图，未支持 grid 等派生主图",
  )
  let iprp = avif_required_node(children, "iprp", meta)
  let property_boxes = avif_nodes(prefix, iprp.payload, iprp.end, budget)
  let ipco = avif_required_node(property_boxes, "ipco", iprp)
  for child in property_boxes {
    if child.kind == "free" || child.kind == "skip" {
      continue
    }
    avif_need(
      child.kind == "ipco",
      "PROPERTY_BOX_ORDER",
      "iprp",
      child.header,
      None,
      "ipco 必须位于属性关联盒之前",
    )
    break
  }
  let properties = avif_nodes(prefix, ipco.payload, ipco.end, budget)
  let associations = avif_associations(
    prefix, property_boxes, properties, items, budget,
  )
  let selected = match associations.get(primary) {
    Some(indexes) => indexes
    None =>
      avif_fault(
        "MISSING_PRIMARY_ASSOCIATION",
        "iprp",
        iprp.payload,
        Some(primary),
        "主图没有属性关联条目",
      )
  }
  let (width, height, primary_properties) = avif_primary_properties(
    prefix, properties, selected, primary, ipco,
  )
  let media : Array[AvifNode] = []
  for node in top {
    if node.kind == "mdat" {
      media.push(node)
    }
  }
  let extents = avif_locations(
    prefix,
    avif_required_node(children, "iloc", meta),
    items,
    primary,
    media,
    avif_optional_node(children, "idat"),
    file_size,
    budget,
  )
  {
    primary_item_id: primary,
    width,
    height,
    item_count: items.length(),
    primary_properties,
    extents,
  }
}

///|
/// Inspect a complete file's leading prefix plus its actual file size.
/// Limits: 4 MiB prefix; 4096 visited boxes, associations and extents;
/// 256 declared items. All required metadata and top-level box headers must
/// be in the prefix; a final mdat payload may extend beyond it.
pub fn inspect_avif_structure(
  prefix : Bytes,
  file_size : Int64,
) -> Result[AvifStructure, AvifDiagnostic] {
  let structure = avif_inspect(prefix, file_size) catch {
    AvifStructureFailure::AvifFault(diagnostic) => return Err(diagnostic)
  }
  Ok(structure)
}

///|
fn avif_diagnostic_message(diagnostic : AvifDiagnostic) -> String {
  let item = match diagnostic.item_id {
    Some(id) => " item=\{id}"
    None => ""
  }
  "AVIF[\{diagnostic.code}] box=\{diagnostic.box_type} offset=\{diagnostic.offset}\{item}: \{diagnostic.detail}"
}
