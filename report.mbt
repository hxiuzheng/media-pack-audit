///|
pub fn html_escape(value : String) -> String {
  let output = StringBuilder()
  for character in value {
    match character {
      '&' => output <+ "&amp;"
      '<' => output <+ "&lt;"
      '>' => output <+ "&gt;"
      '"' => output <+ "&quot;"
      '\'' => output <+ "&#39;"
      _ => output <+ "\{character}"
    }
  }
  output.to_string()
}

///|
pub fn render_html(report : AuditReport) -> String {
  let output = StringBuilder()
  output <+
    #|<!doctype html>
  output <+
    #|<html lang="zh-CN">
  output <+
    #|<head>
  output <+
    #|  <meta charset="utf-8">
  output <+
    #|  <meta name="viewport" content="width=device-width, initial-scale=1">
  output <+
    #|  <title>片盒点检 · 素材交付报告</title>
  output <+
    #|  <style>
  output <+
    #|    :root { color-scheme: dark; --bg:#0b1020; --panel:#121a2e; --line:#273550; --text:#e8efff; --muted:#91a1bd; --cyan:#59e1d0; --red:#ff7b87; --green:#73e0aa; }
  output <+
    #|    * { box-sizing:border-box; }
  output <+
    #|    body { margin:0; background:radial-gradient(circle at 10% 0%,#172544 0,transparent 38%),var(--bg); color:var(--text); font:15px/1.55 "Segoe UI","Microsoft YaHei",sans-serif; }
  output <+
    #|    main { max-width:1080px; margin:0 auto; padding:48px 22px 72px; }
  output <+
    #|    .eyebrow { color:var(--cyan); font-size:12px; font-weight:700; letter-spacing:.18em; text-transform:uppercase; }
  output <+
    #|    h1 { margin:10px 0 6px; font-size:clamp(30px,5vw,48px); letter-spacing:-.04em; }
  output <+
    #|    .path { color:var(--muted); overflow-wrap:anywhere; }
  output <+
    #|    .cards { display:grid; grid-template-columns:repeat(3,1fr); gap:12px; margin:28px 0; }
  output <+
    #|    .card, .table-wrap { border:1px solid var(--line); border-radius:16px; background:rgba(18,26,46,.88); }
  output <+
    #|    .card { padding:18px 20px; }
  output <+
    #|    .label { color:var(--muted); font-size:13px; }
  output <+
    #|    .number { margin-top:5px; font-size:30px; font-weight:750; }
  output <+
    #|    .good { color:var(--green); } .bad { color:var(--red); }
  output <+
    #|    .table-wrap { overflow:hidden; }
  output <+
    #|    table { width:100%; border-collapse:collapse; text-align:left; }
  output <+
    #|    th,td { padding:15px 16px; border-bottom:1px solid var(--line); vertical-align:top; }
  output <+
    #|    th { color:var(--muted); font-size:12px; letter-spacing:.08em; text-transform:uppercase; }
  output <+
    #|    tr:last-child td { border-bottom:0; }
  output <+
    #|    code { color:#d9e5ff; overflow-wrap:anywhere; }
  output <+
    #|    .badge { display:inline-block; border:1px solid currentColor; border-radius:999px; padding:2px 9px; font-size:11px; font-weight:750; letter-spacing:.06em; }
  output <+
    #|    footer { margin-top:18px; color:var(--muted); font-size:12px; }
  output <+
    #|    @media(max-width:700px) { .cards { grid-template-columns:1fr; } th:nth-child(3),td:nth-child(3) { display:none; } main { padding-top:28px; } }
  output <+
    #|  </style>
  output <+
    #|</head>
  output <+
    #|<body><main>
  output <+
    #|  <div class="eyebrow">MEDIA HANDOFF · PREFLIGHT</div>
  output <+
    #|  <h1>片盒点检</h1>
  output <+
    #|  <div class="path">素材目录：<code>
  output.write_string(html_escape(report.asset_dir))
  output <+
    #|</code></div>
  output <+
    #|  <section class="cards">
  output <+
    "    <div class=\"card\"><div class=\"label\">检查项</div><div class=\"number\">\{report.checked}</div></div>\n"
  output <+
    "    <div class=\"card\"><div class=\"label\">通过</div><div class=\"number good\">\{report.passed}</div></div>\n"
  output <+
    "    <div class=\"card\"><div class=\"label\">需处理</div><div class=\"number bad\">\{report.failed}</div></div>\n"
  output <+
    #|  </section>
  output <+
    #|  <div class="table-wrap"><table>
  output <+
    #|    <thead><tr><th>素材</th><th>状态</th><th>检测到</th><th>结果</th></tr></thead>
  output <+
    #|    <tbody>
  for result in report.results {
    let status_class = if result.status == "PASS" { "good" } else { "bad" }
    output <+
      "      <tr><td><code>\{html_escape(result.file)}</code></td><td><span class=\"badge \{status_class}\">\{html_escape(result.status)}</span></td><td>\{html_escape(result.observed)}</td><td>\{html_escape(result.details)}</td></tr>\n"
  }
  output <+
    #|    </tbody>
  output <+
    #|  </table></div>
  output <+
    #|  <footer>片盒点检只读取 PNG/JPEG/GIF 尺寸头和清单信息，不会修改素材文件。</footer>
  output <+
    #|</main></body></html>
  output.to_string()
}
