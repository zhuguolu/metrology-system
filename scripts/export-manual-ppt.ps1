param(
  [string]$InputPath = "",
  [string]$OutputPptxPath = "$env:USERPROFILE\Desktop\metrology-training-deck.pptx"
)

$ErrorActionPreference = "Stop"

function From-CodePoints {
  param([int[]]$Codes)
  return (-join ($Codes | ForEach-Object { [char]$_ }))
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

function New-Rgb {
  param(
    [int]$R,
    [int]$G,
    [int]$B
  )

  return ($R + ($G * 256) + ($B * 65536))
}

function Get-ManualSections {
  param([string]$MarkdownPath)

  $lines = Get-Content -LiteralPath $MarkdownPath -Encoding UTF8
  $title = ""
  $sections = New-Object System.Collections.Generic.List[object]
  $current = $null

  foreach ($rawLine in $lines) {
    $line = [string]$rawLine
    $trimmed = $line.Trim()

    if ($trimmed -match '^#\s+(.+)$' -and -not $title) {
      $title = $matches[1].Trim()
      continue
    }

    if ($trimmed -match '^##\s+(.+)$') {
      if ($null -ne $current) {
        $sections.Add([pscustomobject]$current)
      }

      $current = @{
        Title = $matches[1].Trim()
        Lines = New-Object System.Collections.Generic.List[string]
      }
      continue
    }

    if ($null -ne $current) {
      $current.Lines.Add($trimmed)
    }
  }

  if ($null -ne $current) {
    $sections.Add([pscustomobject]$current)
  }

  return [pscustomobject]@{
    Title = $title
    Sections = $sections
  }
}

function Get-SectionPayload {
  param(
    [object]$Section,
    [string]$TipPrefix,
    [string]$ShotPrefix,
    [string]$StepsPrefix,
    [string]$DefaultShotSuffix
  )

  $body = New-Object System.Collections.Generic.List[string]
  $tips = New-Object System.Collections.Generic.List[string]
  $shotText = ""
  $collectTips = $false

  foreach ($rawLine in $Section.Lines) {
    $line = [string]$rawLine
    $trimmed = $line.Trim()

    if (-not $trimmed -or $trimmed -eq "---") {
      if ($collectTips -and $tips.Count -gt 0) {
        $collectTips = $false
      }
      continue
    }

    if ($trimmed.StartsWith($ShotPrefix)) {
      $collectTips = $false
      $rest = $trimmed.Substring($ShotPrefix.Length).Trim()
      if ($rest) {
        $shotText = $rest
      }
      continue
    }

    if ($trimmed.StartsWith($TipPrefix)) {
      $collectTips = $true
      $rest = $trimmed.Substring($TipPrefix.Length).Trim()
      if ($rest) {
        $tips.Add($rest)
      }
      continue
    }

    if ($trimmed.StartsWith($StepsPrefix)) {
      $rest = $trimmed.Substring($StepsPrefix.Length).Trim()
      if ($rest -and $body.Count -lt 7) {
        $body.Add($rest)
      }
      continue
    }

    if ($trimmed -match '^###\s+(.+)$') {
      if ($body.Count -lt 7) {
        $body.Add($matches[1].Trim())
      }
      $collectTips = $false
      continue
    }

    if ($collectTips) {
      if ($trimmed -match '^- (.+)$') {
        if ($tips.Count -lt 3) {
          $tips.Add($matches[1].Trim())
        }
      }
      else {
        if ($tips.Count -lt 3) {
          $tips.Add($trimmed)
        }
      }
      continue
    }

    if ($trimmed -match '^- (.+)$') {
      if ($body.Count -lt 7) {
        $body.Add($matches[1].Trim())
      }
      continue
    }

    if ($trimmed -match '^\d+\.\s+(.+)$') {
      if ($body.Count -lt 7) {
        $body.Add($matches[1].Trim())
      }
      continue
    }

    if ($body.Count -lt 7) {
      $body.Add($trimmed)
    }
  }

  if (-not $shotText) {
    $shotText = "$($Section.Title) $DefaultShotSuffix"
  }

  if ($tips.Count -eq 0) {
    if ($body.Count -gt 0) {
      $tips.Add($body[0])
    }
    if ($body.Count -gt 1) {
      $tips.Add($body[1])
    }
  }

  $bodyText = if ($body.Count) { "• " + ($body -join "`r`n• ") } else { "• -" }
  $tipText = if ($tips.Count) { ($tips -join "  ·  ") } else { "-" }

  return [pscustomobject]@{
    BodyText = $bodyText
    TipText = $tipText
    ShotText = $shotText
  }
}

function Add-TextShape {
  param(
    $Slide,
    [float]$Left,
    [float]$Top,
    [float]$Width,
    [float]$Height,
    [string]$Text,
    [int]$FontSize,
    [int]$Color,
    [string]$FontName = "Microsoft YaHei",
    [bool]$Bold = $false,
    [int]$ParagraphAlign = 1
  )

  $shape = $Slide.Shapes.AddTextbox(1, $Left, $Top, $Width, $Height)
  $shape.TextFrame.TextRange.Text = $Text
  $shape.TextFrame.TextRange.Font.Name = $FontName
  $shape.TextFrame.TextRange.Font.Size = $FontSize
  $shape.TextFrame.TextRange.Font.Bold = [int]$Bold
  $shape.TextFrame.TextRange.Font.Color.RGB = $Color
  $shape.TextFrame.TextRange.ParagraphFormat.Alignment = $ParagraphAlign
  $shape.TextFrame.WordWrap = -1
  $shape.TextFrame.MarginLeft = 4
  $shape.TextFrame.MarginRight = 4
  $shape.TextFrame.MarginTop = 2
  $shape.TextFrame.MarginBottom = 2
  return $shape
}

function Add-Rect {
  param(
    $Slide,
    [float]$Left,
    [float]$Top,
    [float]$Width,
    [float]$Height,
    [int]$FillColor,
    [int]$LineColor,
    [float]$LineWeight = 1.0,
    [bool]$Dashed = $false
  )

  $shape = $Slide.Shapes.AddShape(1, $Left, $Top, $Width, $Height)
  $shape.Fill.ForeColor.RGB = $FillColor
  $shape.Line.ForeColor.RGB = $LineColor
  $shape.Line.Weight = $LineWeight
  if ($Dashed) {
    $shape.Line.DashStyle = 4
  }
  return $shape
}

function Add-Footer {
  param(
    $Slide,
    [string]$CompanyName,
    [int]$SlideNo,
    [int]$AccentColor,
    [int]$MutedColor
  )

  $null = Add-Rect -Slide $Slide -Left 40 -Top 504 -Width 880 -Height 1 -FillColor $AccentColor -LineColor $AccentColor -LineWeight 0.5
  $null = Add-TextShape -Slide $Slide -Left 44 -Top 510 -Width 600 -Height 18 -Text $CompanyName -FontSize 9 -Color $MutedColor
  $null = Add-TextShape -Slide $Slide -Left 840 -Top 510 -Width 70 -Height 18 -Text ("P." + $SlideNo) -FontSize 9 -Color $MutedColor -ParagraphAlign 3
}

function Add-ContentSlide {
  param(
    $Slides,
    [int]$Index,
    [string]$Title,
    [string]$SectionNo,
    [string]$BodyText,
    [string]$TipText,
    [string]$ShotText,
    [string]$CompanyName,
    [string]$LabelBody,
    [string]$LabelTip,
    [string]$LabelShot,
    [string]$ShotHint
  )

  $cDark = New-Rgb 15 23 42
  $cText = New-Rgb 51 65 85
  $cMuted = New-Rgb 100 116 139
  $cBlue = New-Rgb 29 78 216
  $cSoft = New-Rgb 239 246 255
  $cSoft2 = New-Rgb 248 250 252
  $cBorder = New-Rgb 191 219 254

  $slide = $Slides.Add($Index, 12)
  $null = Add-Rect -Slide $slide -Left 0 -Top 0 -Width 960 -Height 540 -FillColor (New-Rgb 255 255 255) -LineColor (New-Rgb 255 255 255)
  $null = Add-Rect -Slide $slide -Left 0 -Top 0 -Width 14 -Height 540 -FillColor $cBlue -LineColor $cBlue
  $null = Add-TextShape -Slide $slide -Left 42 -Top 26 -Width 70 -Height 22 -Text $SectionNo -FontSize 14 -Color $cBlue -Bold $true
  $null = Add-TextShape -Slide $slide -Left 42 -Top 52 -Width 840 -Height 34 -Text $Title -FontSize 24 -Color $cDark -Bold $true

  $bodyCard = Add-Rect -Slide $slide -Left 42 -Top 104 -Width 360 -Height 344 -FillColor $cSoft2 -LineColor $cBorder
  $tipCard = Add-Rect -Slide $slide -Left 430 -Top 404 -Width 488 -Height 76 -FillColor $cSoft -LineColor $cBorder
  $shotCard = Add-Rect -Slide $slide -Left 430 -Top 104 -Width 488 -Height 280 -FillColor (New-Rgb 255 255 255) -LineColor $cBlue -LineWeight 1.5 -Dashed $true

  $null = Add-TextShape -Slide $slide -Left 58 -Top 122 -Width 120 -Height 20 -Text $LabelBody -FontSize 12 -Color $cBlue -Bold $true
  $null = Add-TextShape -Slide $slide -Left 58 -Top 152 -Width 324 -Height 272 -Text $BodyText -FontSize 15 -Color $cText

  $null = Add-TextShape -Slide $slide -Left 452 -Top 122 -Width 160 -Height 20 -Text $LabelShot -FontSize 12 -Color $cBlue -Bold $true
  $null = Add-TextShape -Slide $slide -Left 470 -Top 182 -Width 408 -Height 34 -Text $LabelShot -FontSize 22 -Color $cBlue -Bold $true -ParagraphAlign 2
  $null = Add-TextShape -Slide $slide -Left 470 -Top 228 -Width 408 -Height 70 -Text $ShotText -FontSize 16 -Color $cText -ParagraphAlign 2
  $null = Add-TextShape -Slide $slide -Left 470 -Top 312 -Width 408 -Height 34 -Text $ShotHint -FontSize 11 -Color $cMuted -ParagraphAlign 2

  $null = Add-TextShape -Slide $slide -Left 452 -Top 420 -Width 120 -Height 20 -Text $LabelTip -FontSize 12 -Color $cBlue -Bold $true
  $null = Add-TextShape -Slide $slide -Left 452 -Top 444 -Width 440 -Height 24 -Text $TipText -FontSize 12 -Color $cText

  Add-Footer -Slide $slide -CompanyName $CompanyName -SlideNo ($Index) -AccentColor $cBorder -MutedColor $cMuted
}

$manual = Get-ManualSections -MarkdownPath (Resolve-InputPath -PathValue $InputPath)

$companyName = From-CodePoints @(24120,24030,38647,21033,30005,26426,31185,25216,26377,38480,20844,21496)
$deckLabel = From-CodePoints @(22521,35757,25945,26448,29256)
$tocLabel = From-CodePoints @(30446,24405)
$bodyLabel = From-CodePoints @(39029,38754,35201,28857)
$tipLabel = From-CodePoints @(22521,35757,25552,31034)
$shotLabel = From-CodePoints @(25130,22270,21344,20301)
$shotPrefix = From-CodePoints @(25130,22270,24314,35758,65306)
$tipPrefix = From-CodePoints @(22521,35757,25552,31034,65306)
$stepsPrefix = From-CodePoints @(25805,20316,27493,39588,65306)
$shotHint = From-CodePoints @(35831,26367,25442,20026,23545,24212,31995,32479,30495,23454,25130,22270)
$defaultShotSuffix = From-CodePoints @(39029,38754,25130,22270)
$audienceLabel = From-CodePoints @(36866,29992,23545,35937)
$roleText = From-CodePoints @(26222,36890,29992,25143,12289,31649,29702,21592,12289,22806,38142,35775,23458)
$agendaHint = From-CodePoints @(24314,35758,25353,22521,35757,39034,24207,36880,34892,29616,22330,35762,35299)
$subtitleLabel = From-CodePoints @(31995,32479,22521,35757,19982,25805,20316,28436,31034)

$sections = @($manual.Sections | Select-Object -First 19)

$ppt = $null
$presentation = $null

try {
  $ppt = New-Object -ComObject PowerPoint.Application
  $ppt.Visible = -1

  $presentation = $ppt.Presentations.Add()
  $presentation.PageSetup.SlideWidth = 960
  $presentation.PageSetup.SlideHeight = 540

  $slides = $presentation.Slides

  $cDark = New-Rgb 15 23 42
  $cText = New-Rgb 51 65 85
  $cMuted = New-Rgb 100 116 139
  $cBlue = New-Rgb 29 78 216
  $cBlueSoft = New-Rgb 239 246 255
  $cBorder = New-Rgb 191 219 254
  $cWhite = New-Rgb 255 255 255

  $slide1 = $slides.Add(1, 12)
  $null = Add-Rect -Slide $slide1 -Left 0 -Top 0 -Width 960 -Height 540 -FillColor $cWhite -LineColor $cWhite
  $null = Add-Rect -Slide $slide1 -Left 0 -Top 0 -Width 960 -Height 180 -FillColor $cBlueSoft -LineColor $cBlueSoft
  $null = Add-TextShape -Slide $slide1 -Left 56 -Top 58 -Width 320 -Height 22 -Text $companyName -FontSize 14 -Color $cBlue -Bold $true
  $null = Add-TextShape -Slide $slide1 -Left 56 -Top 108 -Width 760 -Height 52 -Text $manual.Title -FontSize 28 -Color $cDark -Bold $true
  $null = Add-TextShape -Slide $slide1 -Left 56 -Top 172 -Width 420 -Height 22 -Text $deckLabel -FontSize 18 -Color $cText
  $null = Add-Rect -Slide $slide1 -Left 56 -Top 252 -Width 260 -Height 120 -FillColor $cWhite -LineColor $cBorder
  $null = Add-TextShape -Slide $slide1 -Left 76 -Top 276 -Width 160 -Height 18 -Text $audienceLabel -FontSize 12 -Color $cBlue -Bold $true
  $null = Add-TextShape -Slide $slide1 -Left 76 -Top 306 -Width 210 -Height 44 -Text $roleText -FontSize 16 -Color $cText
  $null = Add-Rect -Slide $slide1 -Left 342 -Top 252 -Width 576 -Height 190 -FillColor (New-Rgb 248 250 252) -LineColor $cBorder
  $null = Add-TextShape -Slide $slide1 -Left 366 -Top 278 -Width 210 -Height 18 -Text $subtitleLabel -FontSize 12 -Color $cBlue -Bold $true
  $null = Add-TextShape -Slide $slide1 -Left 366 -Top 314 -Width 516 -Height 84 -Text ($companyName + "`r`n" + $manual.Title + "`r`n" + $deckLabel) -FontSize 20 -Color $cDark
  Add-Footer -Slide $slide1 -CompanyName $companyName -SlideNo 1 -AccentColor $cBorder -MutedColor $cMuted

  $slide2 = $slides.Add(2, 12)
  $null = Add-Rect -Slide $slide2 -Left 0 -Top 0 -Width 960 -Height 540 -FillColor $cWhite -LineColor $cWhite
  $null = Add-TextShape -Slide $slide2 -Left 42 -Top 34 -Width 120 -Height 24 -Text $tocLabel -FontSize 16 -Color $cBlue -Bold $true
  $null = Add-TextShape -Slide $slide2 -Left 42 -Top 64 -Width 500 -Height 34 -Text $manual.Title -FontSize 24 -Color $cDark -Bold $true
  $null = Add-TextShape -Slide $slide2 -Left 42 -Top 104 -Width 420 -Height 20 -Text $agendaHint -FontSize 12 -Color $cMuted
  $leftY = 146
  $rightY = 146
  $half = [Math]::Ceiling($sections.Count / 2)
  for ($i = 0; $i -lt $sections.Count; $i++) {
    $secTitle = $sections[$i].Title
    $display = ($i + 1).ToString("00") + "  " + $secTitle
    if ($i -lt $half) {
      $null = Add-TextShape -Slide $slide2 -Left 52 -Top $leftY -Width 390 -Height 22 -Text $display -FontSize 14 -Color $cText
      $leftY += 24
    }
    else {
      $null = Add-TextShape -Slide $slide2 -Left 490 -Top $rightY -Width 390 -Height 22 -Text $display -FontSize 14 -Color $cText
      $rightY += 24
    }
  }
  Add-Footer -Slide $slide2 -CompanyName $companyName -SlideNo 2 -AccentColor $cBorder -MutedColor $cMuted

  $slideIndex = 3
  foreach ($section in $sections) {
    $payload = Get-SectionPayload -Section $section -TipPrefix $tipPrefix -ShotPrefix $shotPrefix -StepsPrefix $stepsPrefix -DefaultShotSuffix $defaultShotSuffix
    Add-ContentSlide `
      -Slides $slides `
      -Index $slideIndex `
      -Title $section.Title `
      -SectionNo ($slideIndex - 2).ToString("00") `
      -BodyText $payload.BodyText `
      -TipText $payload.TipText `
      -ShotText $payload.ShotText `
      -CompanyName $companyName `
      -LabelBody $bodyLabel `
      -LabelTip $tipLabel `
      -LabelShot $shotLabel `
      -ShotHint $shotHint
    $slideIndex++
  }

  $outFull = [System.IO.Path]::GetFullPath($OutputPptxPath)
  $outDir = Split-Path -Parent $outFull
  if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
  }

  if (Test-Path -LiteralPath $outFull) {
    Remove-Item -LiteralPath $outFull -Force
  }

  $presentation.SaveAs($outFull, 24)
  Write-Output "PPT generated at: $outFull"
}
finally {
  if ($presentation) {
    $presentation.Close()
  }
  if ($ppt) {
    $ppt.Quit()
  }
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
}
