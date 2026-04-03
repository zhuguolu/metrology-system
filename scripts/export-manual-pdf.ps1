param(
  [string]$InputPath = "",
  [string]$OutputPdfPath = "$env:USERPROFILE\Desktop\metrology-training-manual-formal.pdf"
)

$ErrorActionPreference = "Stop"

function Resolve-ChromePath {
  $candidates = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
  )

  foreach ($path in $candidates) {
    if (Test-Path -LiteralPath $path) {
      return $path
    }
  }

  throw "No Chrome or Edge executable was found."
}

function Resolve-InputPath {
  param([string]$PathValue)

  if (-not [string]::IsNullOrWhiteSpace($PathValue)) {
    return (Resolve-Path -LiteralPath $PathValue).Path
  }

  $candidate = Get-ChildItem -LiteralPath ".\docs" -Filter "*.md" | Sort-Object Name | Select-Object -First 1
  if (-not $candidate) {
    throw "No markdown file was found under .\docs."
  }

  return $candidate.FullName
}

function Convert-InlineMarkdown {
  param([string]$Text)

  if ([string]::IsNullOrEmpty($Text)) {
    return ""
  }

  $escaped = [System.Net.WebUtility]::HtmlEncode($Text)
  $escaped = [System.Text.RegularExpressions.Regex]::Replace($escaped, '\*\*(.+?)\*\*', '<strong>$1</strong>')
  $escaped = [System.Text.RegularExpressions.Regex]::Replace($escaped, '`(.+?)`', '<code>$1</code>')
  return $escaped
}

function Convert-MarkdownToHtmlBody {
  param([string]$Markdown)

  $lines = [System.Text.RegularExpressions.Regex]::Split($Markdown, '\r\n|\n|\r')
  $html = New-Object System.Collections.Generic.List[string]
  $headingIndex = 0

  $shotPrefix = [string]::Concat(([char]0x622A),([char]0x56FE),([char]0x5EFA),([char]0x8BAE),([char]0xFF1A))
  $tipPrefix = [string]::Concat(([char]0x57F9),([char]0x8BAD),([char]0x63D0),([char]0x793A),([char]0xFF1A))
  $stepsPrefix = [string]::Concat(([char]0x64CD),([char]0x4F5C),([char]0x6B65),([char]0x9AA4),([char]0xFF1A))

  $inUl = $false
  $inOl = $false
  $inParagraph = $false

  function Close-Paragraph {
    if ($script:inParagraph) {
      $html.Add("</p>")
      $script:inParagraph = $false
    }
  }

  function Close-Lists {
    if ($script:inUl) {
      $html.Add("</ul>")
      $script:inUl = $false
    }
    if ($script:inOl) {
      $html.Add("</ol>")
      $script:inOl = $false
    }
  }

  foreach ($rawLine in $lines) {
    $line = [string]$rawLine
    $trimmed = $line.Trim()

    if ($trimmed -eq "") {
      Close-Paragraph
      Close-Lists
      continue
    }

    if ($trimmed -eq "---") {
      Close-Paragraph
      Close-Lists
      $html.Add("<hr />")
      continue
    }

    if ($trimmed.StartsWith($shotPrefix)) {
      Close-Paragraph
      Close-Lists
      $content = $trimmed.Substring($shotPrefix.Length).Trim()
      $contentHtml = Convert-InlineMarkdown $content
      $html.Add("<div class=""shot-box""><div class=""shot-box-badge"">SCREENSHOT</div><div class=""shot-box-title"">截图占位建议</div><div class=""shot-box-desc"">$contentHtml</div></div>")
      continue
    }

    if ($trimmed.StartsWith($tipPrefix)) {
      Close-Paragraph
      Close-Lists
      $content = $trimmed.Substring($tipPrefix.Length).Trim()
      $contentHtml = Convert-InlineMarkdown $content
      $html.Add("<div class=""tip-box""><div class=""tip-box-title"">培训提示</div><div class=""tip-box-desc"">$contentHtml</div></div>")
      continue
    }

    if ($trimmed.StartsWith($stepsPrefix)) {
      Close-Paragraph
      Close-Lists
      $content = $trimmed.Substring($stepsPrefix.Length).Trim()
      $contentHtml = Convert-InlineMarkdown $content
      $html.Add("<div class=""steps-box""><span class=""steps-box-label"">操作步骤</span><span class=""steps-box-text"">$contentHtml</span></div>")
      continue
    }

    if ($trimmed -match '^(#{1,3})\s+(.+)$') {
      Close-Paragraph
      Close-Lists
      $level = $matches[1].Length
      $content = Convert-InlineMarkdown $matches[2]
      $headingIndex++
      $html.Add("<h$level id=""sec-$headingIndex"">$content</h$level>")
      continue
    }

    if ($trimmed -match '^\d+\.\s+(.+)$') {
      Close-Paragraph
      if ($inUl) {
        $html.Add("</ul>")
        $inUl = $false
      }
      if (-not $inOl) {
        $html.Add("<ol>")
        $inOl = $true
      }
      $content = Convert-InlineMarkdown $matches[1]
      $html.Add("<li>$content</li>")
      continue
    }

    if ($trimmed -match '^- (.+)$') {
      Close-Paragraph
      if ($inOl) {
        $html.Add("</ol>")
        $inOl = $false
      }
      if (-not $inUl) {
        $html.Add("<ul>")
        $inUl = $true
      }
      $content = Convert-InlineMarkdown $matches[1]
      $html.Add("<li>$content</li>")
      continue
    }

    if (-not $inParagraph) {
      Close-Lists
      $html.Add("<p>")
      $inParagraph = $true
      $html.Add((Convert-InlineMarkdown $trimmed))
    }
    else {
      $html.Add("<br />" + (Convert-InlineMarkdown $trimmed))
    }
  }

  Close-Paragraph
  Close-Lists
  return ($html -join [Environment]::NewLine)
}

function Get-TocEntries {
  param([string]$Markdown)

  $lines = [System.Text.RegularExpressions.Regex]::Split($Markdown, '\r\n|\n|\r')
  $entries = New-Object System.Collections.Generic.List[object]
  $headingIndex = 0

  foreach ($line in $lines) {
    $trimmed = ([string]$line).Trim()
    if ($trimmed -match '^(#{1,2})\s+(.+)$') {
      $headingIndex++
      $entries.Add([pscustomobject]@{
        Id = "sec-$headingIndex"
        Level = $matches[1].Length
        Title = $matches[2].Trim()
      })
    }
  }

  return $entries
}

$inputFullPath = Resolve-InputPath -PathValue $InputPath
$outputFullPath = [System.IO.Path]::GetFullPath($OutputPdfPath)
$outputDir = Split-Path -Parent $outputFullPath

if (-not (Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$markdown = Get-Content -LiteralPath $inputFullPath -Raw -Encoding UTF8
$tocEntries = Get-TocEntries -Markdown $markdown
$bodyHtml = Convert-MarkdownToHtmlBody -Markdown $markdown
$title = "Metrology Training Manual"
$titleHtml = "&#35745;&#37327;&#31649;&#29702;&#31995;&#32479;&#22521;&#35757;&#29256;&#22270;&#25991;&#25805;&#20316;&#25163;&#20876;"
$companyHtml = "&#24120;&#24030;&#38647;&#21033;&#30005;&#26426;&#31185;&#25216;&#26377;&#38480;&#20844;&#21496;"
$subtitleHtml = "&#31995;&#32479;&#22521;&#35757;&#12289;&#20869;&#37096;&#20132;&#25509;&#19982;&#26085;&#24120;&#26597;&#38405;&#29992;"
$versionHtml = "V1.1"
$exportDate = Get-Date -Format "yyyy-MM-dd"

$tocHtmlList = New-Object System.Collections.Generic.List[string]
foreach ($entry in $tocEntries) {
  $titleText = Convert-InlineMarkdown $entry.Title
  $className = if ($entry.Level -eq 1) { "toc-item level-1" } else { "toc-item level-2" }
  $tocHtmlList.Add("<a class=""$className"" href=""#$($entry.Id)""><span class=""toc-text"">$titleText</span><span class=""toc-line""></span></a>")
}
$tocHtml = $tocHtmlList -join [Environment]::NewLine

$html = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>$title</title>
  <style>
    @page { size: A4; margin: 16mm 14mm 18mm 14mm; }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", sans-serif;
      color: #1f2937;
      background: #eef4ff;
      line-height: 1.75;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .page {
      width: 210mm;
      margin: 0 auto;
      padding: 12mm 0;
    }
    .sheet {
      background: #ffffff;
      border-radius: 18px;
      box-shadow: 0 16px 40px rgba(15, 23, 42, 0.08);
      overflow: hidden;
      border: 1px solid #dbe7ff;
    }
    .pdf-footer {
      position: fixed;
      left: 0;
      right: 0;
      bottom: 0;
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 0 14mm 6mm;
      color: #64748b;
      font-size: 10px;
      pointer-events: none;
      z-index: 20;
    }
    .pdf-footer-page .page-num::after {
      content: counter(page);
    }
    .cover {
      padding: 26mm 18mm 18mm;
      background:
        radial-gradient(circle at top right, rgba(96, 165, 250, 0.28), transparent 30%),
        linear-gradient(135deg, #dbeafe, #eff6ff 46%, #ffffff);
      border-bottom: 1px solid #dbeafe;
    }
    .cover-page {
      min-height: 250mm;
      page-break-after: always;
      display: flex;
      flex-direction: column;
      justify-content: center;
    }
    .cover-topline {
      margin-bottom: 18px;
      color: #1e3a8a;
      font-size: 14px;
      font-weight: 700;
      letter-spacing: 0.04em;
    }
    .cover-kicker {
      display: inline-block;
      padding: 6px 12px;
      border-radius: 999px;
      background: rgba(37, 99, 235, 0.1);
      color: #1d4ed8;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.08em;
    }
    .cover h1 {
      margin: 18px 0 8px;
      font-size: 30px;
      line-height: 1.2;
      color: #0f172a;
    }
    .cover p {
      margin: 0;
      color: #475569;
      font-size: 14px;
    }
    .cover-subtitle {
      max-width: 420px;
      line-height: 1.85;
    }
    .cover-meta-grid {
      margin-top: 32px;
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 12px;
      max-width: 640px;
    }
    .cover-meta-card {
      padding: 16px 14px;
      border-radius: 16px;
      border: 1px solid rgba(147, 197, 253, 0.65);
      background: rgba(255, 255, 255, 0.76);
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.7);
    }
    .cover-meta-label {
      color: #64748b;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
    }
    .cover-meta-value {
      margin-top: 8px;
      color: #0f172a;
      font-size: 18px;
      font-weight: 700;
    }
    .toc-section {
      page-break-after: always;
      padding: 16mm 16mm 14mm;
      background: linear-gradient(180deg, #f8fbff, #ffffff);
      border-bottom: 1px solid #e2e8f0;
    }
    .toc-eyebrow {
      color: #2563eb;
      font-size: 12px;
      font-weight: 800;
      letter-spacing: 0.14em;
      text-transform: uppercase;
    }
    .toc-title {
      margin: 10px 0 18px;
      border-left: none;
      background: none;
      padding-left: 0;
      font-size: 28px;
      border-bottom: 2px solid #dbeafe;
      padding-bottom: 10px;
    }
    .toc-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .toc-item {
      display: flex;
      align-items: center;
      gap: 10px;
      color: #1f2937;
      text-decoration: none;
      font-size: 13px;
      padding: 6px 0;
    }
    .toc-item.level-1 {
      font-weight: 700;
    }
    .toc-item.level-2 {
      padding-left: 18px;
      color: #475569;
    }
    .toc-line {
      flex: 1;
      border-bottom: 1px dashed #cbd5e1;
      transform: translateY(2px);
    }
    .content {
      padding: 12mm 16mm 18mm;
    }
    h1, h2, h3 {
      color: #0f172a;
      page-break-after: avoid;
    }
    h1 {
      margin: 26px 0 14px;
      padding-bottom: 10px;
      font-size: 24px;
      border-bottom: 2px solid #bfdbfe;
    }
    h2 {
      margin: 24px 0 12px;
      padding-left: 10px;
      font-size: 18px;
      border-left: 4px solid #3b82f6;
      background: linear-gradient(90deg, rgba(219, 234, 254, 0.5), rgba(219, 234, 254, 0));
    }
    h3 {
      margin: 18px 0 10px;
      font-size: 15px;
      color: #1d4ed8;
    }
    p { margin: 8px 0; font-size: 13px; }
    ul, ol { margin: 8px 0 10px 22px; padding: 0; font-size: 13px; }
    li { margin: 4px 0; }
    hr { margin: 18px 0; border: none; border-top: 1px dashed #cbd5e1; }
    strong { color: #0f172a; }
    code {
      padding: 1px 6px;
      border-radius: 6px;
      background: #eff6ff;
      color: #1d4ed8;
      font-family: Consolas, "Courier New", monospace;
      font-size: 12px;
    }
    .tip-box,
    .shot-box,
    .steps-box {
      margin: 12px 0 16px;
      border-radius: 16px;
      page-break-inside: avoid;
    }
    .tip-box {
      padding: 14px 16px;
      border: 1px solid #bfdbfe;
      background: linear-gradient(135deg, #eff6ff, #f8fbff);
    }
    .tip-box-title {
      color: #1d4ed8;
      font-size: 12px;
      font-weight: 800;
      letter-spacing: 0.08em;
    }
    .tip-box-desc {
      margin-top: 8px;
      font-size: 13px;
      color: #334155;
    }
    .steps-box {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 12px 14px;
      border: 1px solid #dbeafe;
      background: #ffffff;
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.65);
    }
    .steps-box-label {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-width: 78px;
      height: 28px;
      padding: 0 10px;
      border-radius: 999px;
      background: #dbeafe;
      color: #1d4ed8;
      font-size: 12px;
      font-weight: 800;
    }
    .steps-box-text {
      color: #334155;
      font-size: 13px;
    }
    .shot-box {
      min-height: 104px;
      padding: 14px 16px 16px;
      border: 1.5px dashed #93c5fd;
      background:
        linear-gradient(135deg, rgba(219, 234, 254, 0.42), rgba(255, 255, 255, 0.92)),
        linear-gradient(180deg, #ffffff, #f8fbff);
    }
    .shot-box-badge {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 4px 9px;
      border-radius: 999px;
      background: rgba(37, 99, 235, 0.12);
      color: #1d4ed8;
      font-size: 10px;
      font-weight: 800;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }
    .shot-box-title {
      margin-top: 10px;
      color: #0f172a;
      font-size: 14px;
      font-weight: 800;
    }
    .shot-box-desc {
      margin-top: 8px;
      color: #475569;
      font-size: 13px;
    }
    @media print {
      body { background: #ffffff; }
      .page { width: auto; margin: 0; padding: 0; }
      .sheet { box-shadow: none; border: none; border-radius: 0; }
      .pdf-footer { position: fixed; }
    }
  </style>
</head>
<body>
  <div class="pdf-footer">
    <div class="pdf-footer-company">$companyHtml</div>
    <div class="pdf-footer-page">Page <span class="page-num"></span></div>
  </div>
  <div class="page">
    <div class="sheet">
      <section class="cover cover-page">
        <div class="cover-topline">$companyHtml</div>
        <div class="cover-kicker">Training Manual</div>
        <h1>$titleHtml</h1>
        <p class="cover-subtitle">$subtitleHtml</p>
        <div class="cover-meta-grid">
          <div class="cover-meta-card">
            <div class="cover-meta-label">Version</div>
            <div class="cover-meta-value">$versionHtml</div>
          </div>
          <div class="cover-meta-card">
            <div class="cover-meta-label">Export Date</div>
            <div class="cover-meta-value">$exportDate</div>
          </div>
          <div class="cover-meta-card">
            <div class="cover-meta-label">Document Type</div>
            <div class="cover-meta-value">PDF</div>
          </div>
        </div>
      </section>
      <section class="toc-section">
        <div class="toc-eyebrow">Contents</div>
        <h2 class="toc-title">&#30446;&#24405;</h2>
        <div class="toc-list">
          $tocHtml
        </div>
      </section>
      <div class="content">
        $bodyHtml
      </div>
    </div>
  </div>
</body>
</html>
"@

$tempHtmlPath = Join-Path $env:TEMP "metrology-training-manual.html"
Set-Content -LiteralPath $tempHtmlPath -Value $html -Encoding UTF8

$chromePath = Resolve-ChromePath
$htmlUri = [System.Uri]::new($tempHtmlPath).AbsoluteUri

if (Test-Path -LiteralPath $outputFullPath) {
  Remove-Item -LiteralPath $outputFullPath -Force
}

& $chromePath `
  --headless=new `
  --disable-gpu `
  --allow-file-access-from-files `
  --print-to-pdf-no-header `
  "--print-to-pdf=$outputFullPath" `
  $htmlUri | Out-Null

if (-not (Test-Path -LiteralPath $outputFullPath)) {
  throw "PDF export failed."
}

Write-Output "PDF generated at: $outputFullPath"
