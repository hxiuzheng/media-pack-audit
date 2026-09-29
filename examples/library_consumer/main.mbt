///|
/// A separate package that consumes the public audit library API.
async fn main {
  let manifest_path = "examples/library_consumer/media-pack.json"
  let asset_dir = "examples/clean/assets"
  let manifest_bytes = @fs.read_file(manifest_path)
  let manifest = @audit.parse_manifest_json(manifest_bytes.text()) catch {
    error => raise error
  }
  let manifest_sha256 = @audit.sha256_bytes(manifest_bytes.binary())
  let report = @audit.scan_assets(asset_dir, manifest, manifest_sha256)
  let json_report = @json.to_json(report).stringify()
  let html_report = @audit.render_html(report)

  println(
    "库调用完成：{report.checked} 项，{report.passed} 项通过，{report.failed} 项需处理",
  )
  println("清单 SHA-256：{report.manifest_sha256}")
  println("JSON 报告字符数：{json_report.length()}")
  println("HTML 报告字符数：{html_report.length()}")
}
