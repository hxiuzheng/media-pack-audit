///|
/// Read at most 4 MiB and validate the supported AVIF structural subset.
/// IO errors and observed size changes are returned as diagnostics. This is
/// not an atomic snapshot: same-size concurrent edits cannot be detected here.
pub async fn inspect_avif_file(
  path : String,
) -> Result[AvifStructure, AvifDiagnostic] {
  let result = try {
    let size = @fs.file_size(path)
    let length = if size > 4_194_304L { 4_194_304 } else { Int64::to_int(size) }
    let file = @fs.open(path, mode=@fs.ReadOnly)
    defer file.close()
    let prefix = file.read_exactly_at(length, position=0L)
    if @fs.file_size(path) != size {
      Err({
        code: "FILE_CHANGED",
        box_type: "file",
        offset: 0L,
        item_id: None,
        detail: "读取期间文件大小发生变化，请对稳定的文件重试",
      })
    } else {
      inspect_avif_structure(prefix, size)
    }
  } catch {
    _ =>
      Err({
        code: "IO_ERROR",
        box_type: "file",
        offset: 0L,
        item_id: None,
        detail: "无法读取 AVIF 元数据或获取文件大小",
      })
  }
  result
}
