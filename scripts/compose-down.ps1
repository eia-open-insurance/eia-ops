<#
.SYNOPSIS
Stops the local EIA Docker Compose stack.

.PARAMETER Volumes
Also remove the PostgreSQL named volume (destroys local data).

.EXAMPLE
pwsh ./scripts/compose-down.ps1
pwsh ./scripts/compose-down.ps1 -Volumes
#>
[CmdletBinding()]
param(
    [switch]$Volumes
)

. "$PSScriptRoot\_common.ps1"

$docker = Get-DockerPath
$opsRoot = Get-OpsRoot
$composeFile = Join-Path $opsRoot 'compose\docker-compose.yml'
$composeDir = Split-Path -Parent $composeFile
$envFileArgs = @()
$envFile = Join-Path $composeDir '.env'
if (Test-Path -LiteralPath $envFile) {
    $envFileArgs = @('--env-file', $envFile)
}

$arguments = @('compose', '-f', $composeFile) + $envFileArgs + @('down')
$volumeLabel = ''
if ($Volumes) {
    $arguments += '--volumes'
    $volumeLabel = ' --volumes'
}

Write-Host "==> docker compose down$volumeLabel"
& $docker @arguments
if ($LASTEXITCODE -ne 0) {
    throw "docker compose down failed with exit code $LASTEXITCODE"
}
Write-Host 'Stack stopped.'
