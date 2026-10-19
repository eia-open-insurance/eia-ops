# Shared helpers for the eia-ops local deployment scripts. Dot-source this file.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:OpsRoot = Split-Path -Parent $PSScriptRoot
$script:ReposRoot = Split-Path -Parent $script:OpsRoot
$script:WorkspaceRoot = Split-Path -Parent $script:ReposRoot

function Get-OpsRoot {
    return $script:OpsRoot
}

function Get-ReposRoot {
    return $script:ReposRoot
}

function Find-ToolPath {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$Candidates = @()
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }
    return $null
}

function Get-DockerPath {
    $path = Find-ToolPath -Name 'docker' -Candidates @(
        'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
    )
    if (-not $path) {
        throw 'The docker CLI was not found. Install Docker Desktop and reopen the terminal.'
    }
    return $path
}

function Get-KubectlPath {
    $path = Find-ToolPath -Name 'kubectl' -Candidates @(
        'C:\Program Files\Docker\Docker\resources\bin\kubectl.exe',
        'C:\Program Files\Kubernetes\kubectl.exe'
    )
    if (-not $path) {
        throw 'kubectl was not found. Docker Desktop ships it under resources\bin; add it to PATH.'
    }
    return $path
}

function Get-KindPath {
    return Find-ToolPath -Name 'kind' -Candidates @(
        'C:\Program Files\kind\kind.exe',
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\kind.exe'),
        'C:\ProgramData\chocolatey\bin\kind.exe'
    )
}

function Get-MinikubePath {
    return Find-ToolPath -Name 'minikube' -Candidates @(
        'C:\Program Files\Kubernetes\Minikube\minikube.exe'
    )
}

function Get-HelmPath {
    return Find-ToolPath -Name 'helm' -Candidates @(
        'C:\Program Files\Helm\helm.exe',
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\helm.exe'),
        'C:\ProgramData\chocolatey\bin\helm.exe',
        (Join-Path $env:USERPROFILE 'scoop\shims\helm.exe')
    )
}

function Test-DockerEngine {
    $docker = Get-DockerPath
    & $docker info *> $null
    return ($LASTEXITCODE -eq 0)
}

function Assert-DockerEngine {
    if (Test-DockerEngine) {
        return
    }
    throw @'
Docker engine is not running, so container builds and Kubernetes clusters cannot start.

Known blocker on this machine: Docker Desktop / WSL2 has the WSL optional component
enabled but not active until Windows restarts. Docker Desktop reports HTTP 500 for the
dockerDesktopLinuxEngine pipe, and `wsl --status` returns WSL_E_WSL_OPTIONAL_COMPONENT_REQUIRED.

Fix (operator action): restart Windows, start Docker Desktop, then confirm:
  docker version
  docker run --rm hello-world
  wsl --status

See ../README.md ("Current blocker") for the recorded evidence.
'@
}

$script:JavaServices = @(
    [pscustomobject]@{ Name = 'gateway'; Repo = 'eia-platform/gateway'; GradleDir = 'eia-platform'; GradleTask = ':gateway:bootJar'; JarPattern = 'gateway-*-SNAPSHOT.jar'; Dockerfile = 'images/platform/gateway.Dockerfile'; Port = 8080 }
    [pscustomobject]@{ Name = 'auth'; Repo = 'eia-platform/auth'; GradleDir = 'eia-platform'; GradleTask = ':auth:bootJar'; JarPattern = 'auth-*-SNAPSHOT.jar'; Dockerfile = 'images/platform/auth.Dockerfile'; Port = 9000 }
    [pscustomobject]@{ Name = 'config'; Repo = 'eia-platform/config'; GradleDir = 'eia-platform'; GradleTask = ':config:bootJar'; JarPattern = 'config-*-SNAPSHOT.jar'; Dockerfile = 'images/platform/config.Dockerfile'; Port = 8888 }
    [pscustomobject]@{ Name = 'lineage'; Repo = 'eia-platform/lineage'; GradleDir = 'eia-platform'; GradleTask = ':lineage:bootJar'; JarPattern = 'lineage-*-SNAPSHOT.jar'; Dockerfile = 'images/platform/lineage.Dockerfile'; Port = 8101 }

    [pscustomobject]@{ Name = 'party-expert'; Repo = 'eia-party-expert'; GradleDir = 'eia-party-expert'; GradleTask = 'bootJar'; JarPattern = 'eia-party-expert-*-SNAPSHOT.jar'; Dockerfile = 'images/verticals/party-expert.Dockerfile'; Port = 8081 }
    [pscustomobject]@{ Name = 'party-domain'; Repo = 'eia-party-domain'; GradleDir = 'eia-party-domain'; GradleTask = 'bootJar'; JarPattern = 'eia-party-domain-*-SNAPSHOT.jar'; Dockerfile = 'images/verticals/party-domain.Dockerfile'; Port = 8082 }
    [pscustomobject]@{ Name = 'policy-expert'; Repo = 'eia-policy-expert'; GradleDir = 'eia-policy-expert'; GradleTask = 'bootJar'; JarPattern = 'eia-policy-expert-*-SNAPSHOT.jar'; Dockerfile = $null; Port = 8083 }
    [pscustomobject]@{ Name = 'policy-domain'; Repo = 'eia-policy-domain'; GradleDir = 'eia-policy-domain'; GradleTask = 'bootJar'; JarPattern = 'eia-policy-domain-*-SNAPSHOT.jar'; Dockerfile = $null; Port = 8084 }
    [pscustomobject]@{ Name = 'contract-expert'; Repo = 'eia-contract-expert'; GradleDir = 'eia-contract-expert'; GradleTask = 'bootJar'; JarPattern = 'eia-contract-expert-*-SNAPSHOT.jar'; Dockerfile = 'images/verticals/contract-expert.Dockerfile'; Port = 8085 }
    [pscustomobject]@{ Name = 'contract-domain'; Repo = 'eia-contract-domain'; GradleDir = 'eia-contract-domain'; GradleTask = 'bootJar'; JarPattern = 'eia-contract-domain-*-SNAPSHOT.jar'; Dockerfile = 'images/verticals/contract-domain.Dockerfile'; Port = 8086 }
    [pscustomobject]@{ Name = 'direct-claims-expert'; Repo = 'eia-direct-claims-expert'; GradleDir = 'eia-direct-claims-expert'; GradleTask = 'bootJar'; JarPattern = 'eia-direct-claims-expert-*-SNAPSHOT.jar'; Dockerfile = 'images/verticals/direct-claims-expert.Dockerfile'; Port = 8087 }
    [pscustomobject]@{ Name = 'direct-claims-domain'; Repo = 'eia-direct-claims-domain'; GradleDir = 'eia-direct-claims-domain'; GradleTask = 'bootJar'; JarPattern = 'eia-direct-claims-domain-*-SNAPSHOT.jar'; Dockerfile = 'images/verticals/direct-claims-domain.Dockerfile'; Port = 8088 }
    [pscustomobject]@{ Name = 'assumed-claims-expert'; Repo = 'eia-assumed-claims-expert'; GradleDir = 'eia-assumed-claims-expert'; GradleTask = 'bootJar'; JarPattern = 'eia-assumed-claims-expert-*-SNAPSHOT.jar'; Dockerfile = 'images/verticals/assumed-claims-expert.Dockerfile'; Port = 8089 }
    [pscustomobject]@{ Name = 'assumed-claims-domain'; Repo = 'eia-assumed-claims-domain'; GradleDir = 'eia-assumed-claims-domain'; GradleTask = 'bootJar'; JarPattern = 'eia-assumed-claims-domain-*-SNAPSHOT.jar'; Dockerfile = 'images/verticals/assumed-claims-domain.Dockerfile'; Port = 8090 }
    [pscustomobject]@{ Name = 'cession-expert'; Repo = 'eia-cession-expert'; GradleDir = 'eia-cession-expert'; GradleTask = 'bootJar'; JarPattern = 'eia-cession-expert-*-SNAPSHOT.jar'; Dockerfile = $null; Port = 8091 }
    [pscustomobject]@{ Name = 'cession-domain'; Repo = 'eia-cession-domain'; GradleDir = 'eia-cession-domain'; GradleTask = 'bootJar'; JarPattern = 'eia-cession-domain-*-SNAPSHOT.jar'; Dockerfile = $null; Port = 8092 }
    [pscustomobject]@{ Name = 'retrocession-expert'; Repo = 'eia-retrocession-expert'; GradleDir = 'eia-retrocession-expert'; GradleTask = 'bootJar'; JarPattern = 'eia-retrocession-expert-*-SNAPSHOT.jar'; Dockerfile = 'images/verticals/retrocession-expert.Dockerfile'; Port = 8093 }
    [pscustomobject]@{ Name = 'retrocession-domain'; Repo = 'eia-retrocession-domain'; GradleDir = 'eia-retrocession-domain'; GradleTask = 'bootJar'; JarPattern = 'eia-retrocession-domain-*-SNAPSHOT.jar'; Dockerfile = 'images/verticals/retrocession-domain.Dockerfile'; Port = 8094 }
    [pscustomobject]@{ Name = 'document-expert'; Repo = 'eia-document-expert'; GradleDir = 'eia-document-expert'; GradleTask = 'bootJar'; JarPattern = 'eia-document-expert-*-SNAPSHOT.jar'; Dockerfile = 'images/verticals/document-expert.Dockerfile'; Port = 8095 }
    [pscustomobject]@{ Name = 'document-domain'; Repo = 'eia-document-domain'; GradleDir = 'eia-document-domain'; GradleTask = 'bootJar'; JarPattern = 'eia-document-domain-*-SNAPSHOT.jar'; Dockerfile = 'images/verticals/document-domain.Dockerfile'; Port = 8096 }
    [pscustomobject]@{ Name = 'payment-expert'; Repo = 'eia-payment-expert'; GradleDir = 'eia-payment-expert'; GradleTask = 'bootJar'; JarPattern = 'eia-payment-expert-*-SNAPSHOT.jar'; Dockerfile = $null; Port = 8097 }
    [pscustomobject]@{ Name = 'payment-domain'; Repo = 'eia-payment-domain'; GradleDir = 'eia-payment-domain'; GradleTask = 'bootJar'; JarPattern = 'eia-payment-domain-*-SNAPSHOT.jar'; Dockerfile = $null; Port = 8098 }
    [pscustomobject]@{ Name = 'notifications-expert'; Repo = 'eia-notifications-expert'; GradleDir = 'eia-notifications-expert'; GradleTask = 'bootJar'; JarPattern = 'eia-notifications-expert-*-SNAPSHOT.jar'; Dockerfile = $null; Port = 8099 }
    [pscustomobject]@{ Name = 'notifications-domain'; Repo = 'eia-notifications-domain'; GradleDir = 'eia-notifications-domain'; GradleTask = 'bootJar'; JarPattern = 'eia-notifications-domain-*-SNAPSHOT.jar'; Dockerfile = $null; Port = 8100 }
)

function Get-EiaJavaServices {
    return $script:JavaServices
}

function Get-EiaImages {
    param([string]$Tag = 'local')

    $images = @($script:JavaServices | ForEach-Object { "eia/$($_.Name):$Tag" })
    $images += "eia/shell:$Tag"
    return $images
}
