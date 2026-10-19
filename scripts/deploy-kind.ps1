<#
.SYNOPSIS
Creates or reuses a kind cluster, loads the local images, and applies k8s/.

.DESCRIPTION
Requires Docker Desktop's Linux engine, kind, kubectl and a completed local image build.
Use -WithIngress to install the kind ingress-nginx controller (needs network access).
Without an ingress controller the Ingress object is inert; use the printed port-forward
commands instead.

.PARAMETER ClusterName
kind cluster name. Default: eia-local.

.PARAMETER SkipBuild
Load the images already present in the Docker daemon.

.PARAMETER WithIngress
Install ingress-nginx for kind and wait for its controller.

.PARAMETER TimeoutSeconds
Rollout wait per resource set. Default: 900.

.EXAMPLE
pwsh ./scripts/deploy-kind.ps1 -WithIngress
#>
[CmdletBinding()]
param(
    [string]$ClusterName = 'eia-local',
    [switch]$SkipBuild,
    [switch]$WithIngress,
    [int]$TimeoutSeconds = 900
)

. "$PSScriptRoot\_common.ps1"

$docker = Get-DockerPath
Assert-DockerEngine

$kind = Get-KindPath
if (-not $kind) {
    throw 'kind was not found. Install kind (for example: winget install Kubernetes.kind), reopen the terminal, and rerun.'
}
$kubectl = Get-KubectlPath
$opsRoot = Get-OpsRoot

$clusters = & $kind get clusters 2>$null
if ($clusters -notcontains $ClusterName) {
    Write-Host "==> kind create cluster --name $ClusterName"
    & $kind create cluster --name $ClusterName --config (Join-Path $PSScriptRoot 'kind-config.yaml')
    if ($LASTEXITCODE -ne 0) {
        throw "kind create cluster failed with exit code $LASTEXITCODE"
    }
}
else {
    Write-Host "==> reusing kind cluster '$ClusterName'"
}

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot 'build-images.ps1') -Tag local
    if ($LASTEXITCODE -ne 0) {
        throw 'Image build failed.'
    }
}

Write-Host '==> loading images into kind'
foreach ($image in Get-EiaImages -Tag local) {
    & $kind load docker-image --name $ClusterName $image
    if ($LASTEXITCODE -ne 0) {
        throw "kind load docker-image failed for $image (exit $LASTEXITCODE)"
    }
}

if ($WithIngress) {
    $ingressManifest = 'https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/kind/deploy.yaml'
    Write-Host "==> installing ingress-nginx ($ingressManifest)"
    & $kubectl apply -f $ingressManifest
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl apply for ingress-nginx failed with exit code $LASTEXITCODE"
    }
    Write-Host '==> waiting for ingress-nginx controller'
    & $kubectl -n ingress-nginx wait --for=condition=available deployment/ingress-nginx-controller --timeout="$($TimeoutSeconds)s"
    if ($LASTEXITCODE -ne 0) {
        throw 'ingress-nginx did not become available.'
    }
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

Write-Host ''
Write-Host 'Access without an ingress controller:'
Write-Host '  kubectl -n eia-local port-forward svc/eia-shell 3000:80'
Write-Host '  kubectl -n eia-local port-forward svc/eia-gateway 8080:8080'
if ($WithIngress) {
    Write-Host ''
    Write-Host 'Ingress (kind): add "127.0.0.1 eia.local" to the hosts file, then open http://eia.local:18080'
}
Write-Host ''
Write-Host "Delete the cluster with: kind delete cluster --name $ClusterName"
