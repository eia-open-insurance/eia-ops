<#
.SYNOPSIS
Starts the local EIA stack with Docker Compose.

.DESCRIPTION
Runs `docker compose config --quiet` as a parse check, then `docker compose up`.
If compose/.env exists it is passed explicitly; otherwise the local defaults in
docker-compose.yml apply.

.PARAMETER Build
Rebuild every image before starting.

.PARAMETER Foreground
Run attached instead of detached.

.EXAMPLE
pwsh ./scripts/compose-up.ps1
pwsh ./scripts/compose-up.ps1 -Build
#>
[CmdletBinding()]
param(
    [switch]$Build,
    [switch]$Foreground
)

. "$PSScriptRoot\_common.ps1"

$docker = Get-DockerPath
Assert-DockerEngine

$opsRoot = Get-OpsRoot
$composeFile = Join-Path $opsRoot 'compose\docker-compose.yml'
$composeDir = Split-Path -Parent $composeFile
$envFileArgs = @()
$envFile = Join-Path $composeDir '.env'
if (Test-Path -LiteralPath $envFile) {
    $envFileArgs = @('--env-file', $envFile)
}
else {
    Write-Host "No compose/.env found; using the local defaults. Copy .env.example to .env to override."
}

$base = @('compose', '-f', $composeFile) + $envFileArgs

Write-Host '==> docker compose config --quiet'
& $docker @base config --quiet
if ($LASTEXITCODE -ne 0) {
    throw "docker compose config failed with exit code $LASTEXITCODE"
}

$up = $base + @('up')
if (-not $Foreground) {
    $up += '-d'
}
if ($Build) {
    $up += '--build'
}

Write-Host "==> docker compose $($up -join ' ')"
& $docker @up
if ($LASTEXITCODE -ne 0) {
    throw "docker compose up failed with exit code $LASTEXITCODE"
}

& $docker @base ps

Write-Host ''
Write-Host 'Shell (SPA + /api proxy):  http://localhost:3000'
Write-Host 'Gateway:                   http://localhost:8080/actuator/health'
Write-Host 'Auth:                      http://localhost:9000/actuator/health'
Write-Host 'Config:                    http://localhost:8888/actuator/health'
Write-Host 'Lineage:                   http://localhost:8101/actuator/health'
Write-Host 'Vertical services:         http://localhost:8081-8100/actuator/health'
Write-Host 'PostgreSQL:                localhost:5432 (databases eia_*)'
Write-Host ''
Write-Host 'Federated vertical web remotes are not part of this stack; see README.md.'
