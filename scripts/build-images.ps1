<#
.SYNOPSIS
Builds the local container images for the EIA platform and implemented vertical services.

.DESCRIPTION
Runs the owning repository's Gradle bootJar task (the wrapper is committed in every Java
repository), then builds an image with either the deployment-owned Dockerfile in
repos/eia-ops/images or the repository Dockerfile when it is already correct.
The shell image is built from repos/eia-frontend/shell; rebuild its bundle with
-BuildFrontend after a source change. The ten federated web remotes are packaged from each
repos/eia-<vertical>-web dist/ directory by images/web/remote.Dockerfile, and the FS-RI
simulator test double is packaged from repos/eia-quality by images/simulators/fsri.Dockerfile.

.PARAMETER Tag
Image tag applied to every eia/* image. Default: local.

.PARAMETER JavaHome
JDK 22 home. Defaults to JAVA_HOME, then the toolchain path used by this workspace.

.PARAMETER SkipGradle
Reuse the jars already present under build/libs.

.PARAMETER SkipJava
Do not build or package the Java services.

.PARAMETER BuildFrontend
Run npm ci/npm run build in eia-frontend/shell and in every eia-<vertical>-web repository
even when their dist/ directories already exist.

.PARAMETER SkipShell
Do not build the shell image.

.PARAMETER SkipWeb
Do not build the ten federated web-remote images.

.PARAMETER SkipSimulators
Do not build the FS-RI simulator image.

.EXAMPLE
pwsh ./scripts/build-images.ps1 -Tag local
#>
[CmdletBinding()]
param(
    [string]$Tag = 'local',
    [string]$JavaHome = '',
    [switch]$SkipGradle,
    [switch]$SkipJava,
    [switch]$BuildFrontend,
    [switch]$SkipShell,
    [switch]$SkipWeb,
    [switch]$SkipSimulators
)

. "$PSScriptRoot\_common.ps1"

$docker = Get-DockerPath
Assert-DockerEngine

if (-not $JavaHome) {
    $candidates = @(
        $env:JAVA_HOME,
        'C:\Program Files\Eclipse Adoptium\jdk-22.0.2.9-hotspot'
    ) | Where-Object { $_ }
    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate 'bin\java.exe')) {
            $JavaHome = $candidate
            break
        }
    }
}
if ($JavaHome) {
    $env:JAVA_HOME = $JavaHome
    $env:Path = "$JavaHome\bin;$env:Path"
    Write-Host "JAVA_HOME=$JavaHome"
}
else {
    Write-Warning 'JDK 22 was not found; Gradle will use whatever java is on PATH.'
}

$opsRoot = Get-OpsRoot
$reposRoot = Get-ReposRoot
$built = [System.Collections.Generic.List[string]]::new()
$services = @()
if (-not $SkipJava) {
    $services = Get-EiaJavaServices
}

foreach ($service in $services) {
    $context = Join-Path $reposRoot $service.Repo
    if (-not (Test-Path -LiteralPath $context)) {
        throw "Missing component directory: $context"
    }

    if (-not $SkipGradle) {
        $gradleDir = Join-Path $reposRoot $service.GradleDir
        Write-Host "==> gradle $($service.GradleTask) ($($service.GradleDir))"
        Push-Location $gradleDir
        try {
            & .\gradlew.bat --no-daemon $service.GradleTask -x test
            if ($LASTEXITCODE -ne 0) {
                throw "Gradle task $($service.GradleTask) failed for $($service.GradleDir) with exit code $LASTEXITCODE"
            }
        }
        finally {
            Pop-Location
        }
    }

    $libs = Join-Path $context 'build\libs'
    $jar = Get-ChildItem -Path $libs -Filter $service.JarPattern -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $jar) {
        throw "No jar matching $($service.JarPattern) under $libs. Run without -SkipGradle first."
    }

    if ($service.Dockerfile) {
        $dockerfile = Join-Path $opsRoot $service.Dockerfile
    }
    else {
        $dockerfile = Join-Path $context 'Dockerfile'
    }
    if (-not (Test-Path -LiteralPath $dockerfile)) {
        throw "Missing Dockerfile: $dockerfile"
    }

    $image = "eia/$($service.Name):$Tag"
    Write-Host "==> docker build $image"
    & $docker build -f $dockerfile -t $image $context
    if ($LASTEXITCODE -ne 0) {
        throw "docker build failed for $image (exit $LASTEXITCODE)"
    }
    $built.Add($image)
}

if (-not $SkipShell) {
    $shellDir = Join-Path $reposRoot 'eia-frontend\shell'
    $distIndex = Join-Path $shellDir 'dist\index.html'
    if ($BuildFrontend -or -not (Test-Path -LiteralPath $distIndex)) {
        $npm = Find-ToolPath -Name 'npm' -Candidates @('C:\Program Files\nodejs\npm.cmd')
        if (-not $npm) {
            throw 'npm was not found and the shell dist bundle is missing; install Node 24 / npm 11.'
        }
        Push-Location $shellDir
        try {
            if (-not (Test-Path -LiteralPath (Join-Path $shellDir 'node_modules'))) {
                Write-Host '==> npm ci (eia-frontend/shell)'
                & $npm ci
                if ($LASTEXITCODE -ne 0) {
                    throw "npm ci failed with exit code $LASTEXITCODE"
                }
            }
            Write-Host '==> npm run build (eia-frontend/shell)'
            & $npm run build
            if ($LASTEXITCODE -ne 0) {
                throw "npm run build failed with exit code $LASTEXITCODE"
            }
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Host '==> using existing eia-frontend/shell/dist (pass -BuildFrontend to rebuild)'
    }

    $image = "eia/shell:$Tag"
    Write-Host "==> docker build $image"
    & $docker build -f (Join-Path $shellDir 'Dockerfile') -t $image $shellDir
    if ($LASTEXITCODE -ne 0) {
        throw "docker build failed for $image (exit $LASTEXITCODE)"
    }
    $built.Add($image)
}

if (-not $SkipWeb) {
    $npm = Find-ToolPath -Name 'npm' -Candidates @('C:\Program Files\nodejs\npm.cmd')
    if (-not $npm) {
        throw 'npm was not found and a web-remote dist bundle is missing; install Node 24 / npm 11.'
    }
    foreach ($remote in Get-EiaWebRemotes) {
        $context = Join-Path $reposRoot $remote.Repo
        if (-not (Test-Path -LiteralPath (Join-Path $context 'package.json'))) {
            throw "Missing web component directory: $context"
        }
        $distIndex = Join-Path $context 'dist\index.html'
        if ($BuildFrontend -or -not (Test-Path -LiteralPath $distIndex)) {
            Push-Location $context
            try {
                if (-not (Test-Path -LiteralPath (Join-Path $context 'node_modules'))) {
                    Write-Host "==> npm ci ($($remote.Repo))"
                    & $npm ci
                    if ($LASTEXITCODE -ne 0) {
                        throw "npm ci failed for $($remote.Repo) with exit code $LASTEXITCODE"
                    }
                }
                Write-Host "==> npm run build ($($remote.Repo))"
                & $npm run build
                if ($LASTEXITCODE -ne 0) {
                    throw "npm run build failed for $($remote.Repo) with exit code $LASTEXITCODE"
                }
            }
            finally {
                Pop-Location
            }
        }
        else {
            Write-Host "==> using existing $($remote.Repo)/dist (pass -BuildFrontend to rebuild)"
        }

        $image = "eia/$($remote.Name)-web:$Tag"
        Write-Host "==> docker build $image"
        & $docker build -f (Join-Path $opsRoot 'images\web\remote.Dockerfile') -t $image $context
        if ($LASTEXITCODE -ne 0) {
            throw "docker build failed for $image (exit $LASTEXITCODE)"
        }
        $built.Add($image)
    }
}

if (-not $SkipSimulators) {
    foreach ($simulator in Get-EiaSimulators) {
        $context = Join-Path $reposRoot $simulator.Repo
        $dockerfile = Join-Path $opsRoot $simulator.Dockerfile
        if (-not (Test-Path -LiteralPath $dockerfile)) {
            throw "Missing Dockerfile: $dockerfile"
        }
        $image = "eia/$($simulator.Name):$Tag"
        Write-Host "==> docker build $image"
        & $docker build -f $dockerfile -t $image $context
        if ($LASTEXITCODE -ne 0) {
            throw "docker build failed for $image (exit $LASTEXITCODE)"
        }
        $built.Add($image)
    }
}

Write-Host ''
Write-Host "Built $($built.Count) image(s) with tag '$Tag':"
$built | ForEach-Object { Write-Host "  $_" }
Write-Host ''
Write-Host 'Next: pwsh ./scripts/compose-up.ps1'
