<#
.SYNOPSIS
Starts minikube, loads the local images, and applies k8s/.

.DESCRIPTION
Requires Docker Desktop's Linux engine and minikube. Images are built with the host
Docker CLI and loaded into the minikube node with `minikube image load`.

.PARAMETER Profile
minikube profile. Default: eia-local.

.PARAMETER Cpus
CPUs assigned to the node. Default: 4.

.PARAMETER Memory
Node memory (for example 8192mb or 12g). Default: 8192mb.

.PARAMETER SkipBuild
Load the images already present in the Docker daemon.

.PARAMETER TimeoutSeconds
Rollout wait per resource set. Default: 900.

.EXAMPLE
pwsh ./scripts/deploy-minikube.ps1
pwsh ./scripts/deploy-minikube.ps1 -Memory 12g
#>
[CmdletBinding()]
param(
    [string]$Profile = 'eia-local',
    [int]$Cpus = 4,
    [string]$Memory = '12288mb',
    [switch]$SkipBuild,
    [int]$TimeoutSeconds = 900
)

. "$PSScriptRoot\_common.ps1"

$docker = Get-DockerPath
Assert-DockerEngine

$minikube = Get-MinikubePath
if (-not $minikube) {
    throw 'minikube was not found. Install minikube (for example: winget install Kubernetes.minikube), reopen the terminal, and rerun.'
}
$kubectl = Get-KubectlPath
$opsRoot = Get-OpsRoot

Write-Host "==> minikube start --profile $Profile"
& $minikube start --profile $Profile --driver=docker --cpus=$Cpus --memory=$Memory
if ($LASTEXITCODE -ne 0) {
    throw "minikube start failed with exit code $LASTEXITCODE"
}

Write-Host "==> minikube addons enable ingress --profile $Profile"
& $minikube addons enable ingress --profile $Profile
if ($LASTEXITCODE -ne 0) {
    throw "minikube addons enable ingress failed with exit code $LASTEXITCODE"
}

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot 'build-images.ps1') -Tag local
    if ($LASTEXITCODE -ne 0) {
        throw 'Image build failed.'
    }
}

Write-Host '==> loading images into minikube'
foreach ($image in Get-EiaImages -Tag local) {
    & $minikube --profile $Profile image load $image
    if ($LASTEXITCODE -ne 0) {
        throw "minikube image load failed for $image (exit $LASTEXITCODE)"
    }
}

Write-Host '==> waiting for ingress-nginx controller'
& $kubectl -n ingress-nginx wait --for=condition=available deployment/ingress-nginx-controller --timeout="$($TimeoutSeconds)s"
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'ingress-nginx did not become available; the Ingress will not serve traffic yet.'
}

Write-Host '==> kubectl apply -k k8s'
& $kubectl apply -k (Join-Path $opsRoot 'k8s')
if ($LASTEXITCODE -ne 0) {
    throw "kubectl apply failed with exit code $LASTEXITCODE"
}

Write-Host '==> waiting for deployments'
& $kubectl -n eia-local wait --for=condition=available deployment --all --timeout="$($TimeoutSeconds)s"
if ($LASTEXITCODE -ne 0) {
    throw 'Deployments did not all become available. Inspect: kubectl -n eia-local get pods'
}

& $kubectl -n eia-local get deploy,svc,pods

$ip = & $minikube ip --profile $Profile
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Could not read the minikube IP; run minikube ip manually after the node is ready.'
    $ip = '<minikube-ip>'
}
else {
    $ip = $ip.Trim()
}
Write-Host ''
Write-Host "minikube IP: $ip"
Write-Host "Ingress: add `"$ip eia.local`" to the hosts file, then open http://eia.local"
Write-Host 'If the node IP is not routable from Windows, run `minikube tunnel` in another terminal.'
Write-Host ''
Write-Host 'Port-forward fallback:'
Write-Host '  kubectl -n eia-local port-forward svc/eia-shell 3000:80'
Write-Host '  kubectl -n eia-local port-forward svc/eia-gateway 8080:8080'
Write-Host ''
Write-Host "Stop with: minikube stop --profile $Profile; delete with: minikube delete --profile $Profile"
