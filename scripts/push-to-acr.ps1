param(
  [Parameter(Mandatory = $true)]
  [string]$Registry,
  [Parameter(Mandatory = $true)]
  [string]$Namespace,
  [string]$Tag = ("v" + (Get-Date -Format "yyyyMMdd-HHmm"))
)

$ErrorActionPreference = "Stop"

$backendLocal = "metrology-system-backend:latest"
$frontendLocal = "metrology-system-frontend:latest"

$backendRemote = "$Registry/$Namespace/metrology-backend:$Tag"
$frontendRemote = "$Registry/$Namespace/metrology-frontend:$Tag"

Write-Host "Using tag: $Tag"
Write-Host "Backend target:  $backendRemote"
Write-Host "Frontend target: $frontendRemote"

docker image inspect $backendLocal | Out-Null
docker image inspect $frontendLocal | Out-Null

docker tag $backendLocal $backendRemote
docker tag $frontendLocal $frontendRemote

docker push $backendRemote
docker push $frontendRemote

Write-Host ""
Write-Host "Push completed."
Write-Host "BACKEND_IMAGE=$backendRemote"
Write-Host "FRONTEND_IMAGE=$frontendRemote"
