param(
  [string]$Repo = "zhuguolu/metrology-system",
  [string]$WorkflowFile = "ios-unsigned-ipa.yml",
  [string]$ArtifactName = "ios-app-unsigned-ipa",
  [string]$DestinationDir = "D:\codeWorkSpace\metrology-v2\metrology-system\downloads",
  [string]$Branch = "main",
  [string]$OutputIpaName = "MetrologyiOS-unsigned-latest.ipa"
)

$ErrorActionPreference = "Stop"

function Get-GitHubTokenFromCredentialManager {
  try {
    $gitCmd = Get-Command git -ErrorAction Stop
    $request = "protocol=https`nhost=github.com`n`n"
    $response = $request | & $gitCmd.Source credential-manager get --no-ui 2>$null
    if (-not $response) {
      return $null
    }
    $passwordLine = $response | Where-Object { $_ -like "password=*" } | Select-Object -First 1
    if (-not $passwordLine) {
      return $null
    }
    return ($passwordLine -replace "^password=", "").Trim()
  } catch {
    return $null
  }
}

function Get-GitHubHeaders {
  $headers = @{
    "User-Agent" = "metrology-ipa-sync"
    "Accept"     = "application/vnd.github+json"
  }
  $token = $env:GITHUB_TOKEN
  if (-not $token) {
    $token = Get-GitHubTokenFromCredentialManager
  }
  if ($token) {
    $headers["Authorization"] = "Bearer $token"
  }
  return $headers
}

function Invoke-GitHubJson {
  param([Parameter(Mandatory = $true)][string]$Url)
  return Invoke-RestMethod -Uri $Url -Headers (Get-GitHubHeaders) -Method Get
}

function Invoke-GitHubDownload {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$OutFile
  )
  Invoke-WebRequest -Uri $Url -Headers (Get-GitHubHeaders) -OutFile $OutFile -UseBasicParsing
}

function Remove-OldZipFiles {
  param(
    [Parameter(Mandatory = $true)][string]$Dir,
    [string]$KeepZipPath = ""
  )

  $zipFiles = Get-ChildItem -Path $Dir -Filter *.zip -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
  if (-not $zipFiles -or $zipFiles.Count -le 1) {
    return
  }

  $keepResolved = $null
  if ($KeepZipPath -and (Test-Path -LiteralPath $KeepZipPath)) {
    $keepResolved = (Resolve-Path -LiteralPath $KeepZipPath).Path
  } else {
    $keepResolved = (Resolve-Path -LiteralPath $zipFiles[0].FullName).Path
  }

  foreach ($zip in $zipFiles) {
    $resolved = (Resolve-Path -LiteralPath $zip.FullName).Path
    if ($resolved -ne $keepResolved) {
      Remove-Item -LiteralPath $zip.FullName -Force
    }
  }
}

if (-not (Test-Path -LiteralPath $DestinationDir)) {
  New-Item -Path $DestinationDir -ItemType Directory -Force | Out-Null
}

$stateFile = Join-Path $DestinationDir ".ipa-sync-state.json"
$runsUrl = "https://api.github.com/repos/$Repo/actions/workflows/$WorkflowFile/runs?status=completed&conclusion=success&per_page=20"
$runsResp = Invoke-GitHubJson -Url $runsUrl

if (-not $runsResp.workflow_runs -or $runsResp.workflow_runs.Count -eq 0) {
  throw "No successful workflow runs found for $WorkflowFile"
}

$latestRun = $runsResp.workflow_runs | Where-Object { $_.head_branch -eq $Branch } | Select-Object -First 1
if (-not $latestRun) {
  $latestRun = $runsResp.workflow_runs | Select-Object -First 1
}

$lastRunId = $null
if (Test-Path -LiteralPath $stateFile) {
  try {
    $state = Get-Content -Raw -LiteralPath $stateFile | ConvertFrom-Json
    $lastRunId = [string]$state.run_id
  } catch {
    $lastRunId = $null
  }
}

$outputIpaPath = Join-Path $DestinationDir $OutputIpaName
if ($lastRunId -eq [string]$latestRun.id -and (Test-Path -LiteralPath $outputIpaPath)) {
  Remove-OldZipFiles -Dir $DestinationDir
  Write-Output "Already up to date. run_id=$($latestRun.id), file=$outputIpaPath"
  exit 0
}

$artifactsUrl = "https://api.github.com/repos/$Repo/actions/runs/$($latestRun.id)/artifacts?per_page=100"
$artifactsResp = Invoke-GitHubJson -Url $artifactsUrl
$artifact = $artifactsResp.artifacts | Where-Object { $_.name -eq $ArtifactName -and -not $_.expired } | Select-Object -First 1
if (-not $artifact) {
  $available = ($artifactsResp.artifacts | Select-Object -ExpandProperty name) -join ", "
  throw "Artifact '$ArtifactName' not found for run $($latestRun.id). Available: $available"
}

$zipPath = Join-Path $DestinationDir "$($ArtifactName)-run$($latestRun.run_number).zip"
$extractDir = Join-Path $DestinationDir "_extract_run_$($latestRun.run_number)"

if (Test-Path -LiteralPath $extractDir) {
  Remove-Item -LiteralPath $extractDir -Recurse -Force
}
New-Item -Path $extractDir -ItemType Directory -Force | Out-Null

Invoke-GitHubDownload -Url $artifact.archive_download_url -OutFile $zipPath
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

$ipa = Get-ChildItem -Path $extractDir -Recurse -Filter *.ipa | Select-Object -First 1
if (-not $ipa) {
  throw "No .ipa found after extracting artifact: $zipPath"
}

Copy-Item -LiteralPath $ipa.FullName -Destination $outputIpaPath -Force

$buildInfo = Get-ChildItem -Path $extractDir -Recurse -Filter build-info.txt | Select-Object -First 1
if ($buildInfo) {
  Copy-Item -LiteralPath $buildInfo.FullName -Destination (Join-Path $DestinationDir "latest-build-info.txt") -Force
}

$checksums = Get-ChildItem -Path $extractDir -Recurse -Filter checksums.txt | Select-Object -First 1
if ($checksums) {
  Copy-Item -LiteralPath $checksums.FullName -Destination (Join-Path $DestinationDir "latest-checksums.txt") -Force
}

$newState = [ordered]@{
  repo               = $Repo
  workflow           = $WorkflowFile
  branch             = $latestRun.head_branch
  run_id             = [string]$latestRun.id
  run_number         = [string]$latestRun.run_number
  run_url            = $latestRun.html_url
  downloaded_at      = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
  artifact_name      = $ArtifactName
  artifact_zip       = $zipPath
  output_ipa         = $outputIpaPath
  output_ipa_size    = (Get-Item -LiteralPath $outputIpaPath).Length
}
$newState | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $stateFile -Encoding UTF8

if (Test-Path -LiteralPath $extractDir) {
  Remove-Item -LiteralPath $extractDir -Recurse -Force
}

Remove-OldZipFiles -Dir $DestinationDir -KeepZipPath $zipPath

Write-Output "Downloaded run #$($latestRun.run_number) ($($latestRun.id))"
Write-Output "IPA: $outputIpaPath"
Write-Output "Size(bytes): $((Get-Item -LiteralPath $outputIpaPath).Length)"
