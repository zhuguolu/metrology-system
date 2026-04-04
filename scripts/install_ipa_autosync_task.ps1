param(
  [string]$TaskName = "Metrology-IOS-IPA-AutoSync",
  [int]$IntervalMinutes = 5,
  [string]$Repo = "zhuguolu/metrology-system",
  [string]$WorkflowFile = "ios-unsigned-ipa.yml",
  [string]$ArtifactName = "ios-app-unsigned-ipa",
  [string]$Branch = "main",
  [string]$DestinationDir = "D:\codeWorkSpace\metrology-v2\metrology-system\downloads"
)

$ErrorActionPreference = "Stop"

if ($IntervalMinutes -lt 1) {
  throw "IntervalMinutes must be >= 1"
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$syncScript = Join-Path $scriptRoot "sync_latest_unsigned_ipa.ps1"

if (-not (Test-Path -LiteralPath $syncScript)) {
  throw "Sync script not found: $syncScript"
}

$taskArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$syncScript`" -Repo `"$Repo`" -WorkflowFile `"$WorkflowFile`" -ArtifactName `"$ArtifactName`" -DestinationDir `"$DestinationDir`" -Branch `"$Branch`""
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $taskArguments

$startAt = (Get-Date).AddMinutes(1)
$trigger = New-ScheduledTaskTrigger -Once -At $startAt -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description "Auto sync latest unsigned iOS IPA from GitHub Actions artifact" | Out-Null
Start-ScheduledTask -TaskName $TaskName

Write-Output "Task created: $TaskName"
Write-Output "Interval(min): $IntervalMinutes"
Write-Output "Destination: $DestinationDir"
Write-Output "Action: powershell.exe $taskArguments"
