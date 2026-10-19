<#
.SYNOPSIS
Validates the eia-ops deployment assets.

.DESCRIPTION
Runs five independent checks:
  1. docker compose config --quiet        (Compose schema and substitution)
  2. kubectl kustomize k8s                (offline Kubernetes render)
  3. helm lint + helm template            (offline Helm render, when Helm is installed)
  4. python scripts/validate-yaml.py      (YAML parse, duplicate keys, cross-file invariants)
  5. rendered-output checks in validate-yaml.py (26 Deployments/Services, probes, ports)

PyYAML 6.0.3 is already installed in this workspace's Python 3.12.
No Docker engine, cluster, or network access is required.

.PARAMETER SkipHelm
Skip helm lint/template even if Helm is installed.

.EXAMPLE
pwsh ./scripts/validate.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipHelm
)

. "$PSScriptRoot\_common.ps1"

$opsRoot = Get-OpsRoot
$tempFiles = [System.Collections.Generic.List[string]]::new()
function New-TempFile([string]$Prefix) {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("$Prefix-" + [guid]::NewGuid().ToString('N') + '.yaml')
    $tempFiles.Add($path)
    return $path
}

$exitCode = 0
try {
    Write-Host '== docker compose config =='
    $docker = Get-DockerPath
    $composeFile = Join-Path $opsRoot 'compose\docker-compose.yml'
    & $docker compose -f $composeFile config --quiet
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose config failed with exit code $LASTEXITCODE"
    }
    Write-Host '  OK   compose file parses'

    Write-Host '== kubectl kustomize =='
    $kubectl = Get-KubectlPath
    $kustomizeOut = New-TempFile 'eia-kustomize'
    & $kubectl kustomize (Join-Path $opsRoot 'k8s') > $kustomizeOut
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl kustomize failed with exit code $LASTEXITCODE"
    }
    $kustomizeObjects = (Select-String -Path $kustomizeOut -Pattern '^kind: ').Count
    Write-Host "  OK   kustomize rendered $kustomizeObjects objects"

    $pythonArgs = @(
        (Join-Path $PSScriptRoot 'validate-yaml.py'),
        '--root', $opsRoot,
        '--kubectl-rendered', $kustomizeOut
    )

    $helm = if ($SkipHelm) { $null } else { Get-HelmPath }
    if ($helm) {
        Write-Host '== helm lint / helm template =='
        $chartDir = Join-Path $opsRoot 'helm\eia'
        $helmOut = New-TempFile 'eia-helm'
        & $helm lint $chartDir
        if ($LASTEXITCODE -ne 0) {
            throw "helm lint failed with exit code $LASTEXITCODE"
        }
        & $helm template eia $chartDir > $helmOut
        if ($LASTEXITCODE -ne 0) {
            throw "helm template failed with exit code $LASTEXITCODE"
        }
        $helmObjects = (Select-String -Path $helmOut -Pattern '^kind: ').Count
        Write-Host "  OK   helm rendered $helmObjects objects"
        $pythonArgs += @('--helm-rendered', $helmOut)
    }
    else {
        Write-Warning 'Helm was not found; helm lint/template checks were skipped.'
    }

    Write-Host '== YAML and catalog checks =='
    $python = Find-ToolPath -Name 'python'
    if (-not $python) {
        throw 'Python 3 was not found; it is required for YAML validation.'
    }
    & $python @pythonArgs
    if ($LASTEXITCODE -ne 0) {
        $exitCode = $LASTEXITCODE
    }
}
catch {
    Write-Error $_.Exception.Message
    $exitCode = 1
}
finally {
    foreach ($tempFile in $tempFiles) {
        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($exitCode -eq 0) {
    Write-Host ''
    Write-Host 'VALIDATION PASS'
}
else {
    Write-Host ''
    Write-Host "VALIDATION FAIL (exit $exitCode)"
}

exit $exitCode
