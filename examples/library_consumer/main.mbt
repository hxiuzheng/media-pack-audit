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
  let output_dir = "_build/library-consumer"
  @fs.mkdir(output_dir, recursive=true)
  @fs.write_file("{output_dir}/report.json", json_report)
  @fs.write_file("{output_dir}/report.html", html_report)
  if report.checked != 1 || report.passed != 1 || report.failed != 0 {
    raise Failure::Failure(
      "库消费示例预期 1 项通过，实际 checked={report.checked}, passed={report.passed}, failed={report.failed}",
    )
  }

  println(
    "库调用完成：{report.checked} 项，{report.passed} 项通过，{report.failed} 项需处理",
  )
  println("清单 SHA-256：{report.manifest_sha256}")
  println("JSON 报告：{output_dir}/report.json")
  println("HTML 报告：{output_dir}/report.html")
}
