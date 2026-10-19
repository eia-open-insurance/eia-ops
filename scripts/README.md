# Local scripts

PowerShell 7 scripts for the no-hosted-CI workflow. All scripts resolve the workspace from
their own location; they can be run from any directory.

| Script | Purpose |
|---|---|
| `build-images.ps1` | Run Gradle `bootJar` per component and build the `eia/*:local` images |
| `compose-up.ps1` | Parse-check and start the Compose stack |
| `compose-down.ps1` | Stop the stack; `-Volumes` also deletes PostgreSQL data |
| `deploy-kind.ps1` | Create/reuse a kind cluster, load images, apply `k8s/` |
| `deploy-minikube.ps1` | Start minikube, enable ingress, load images, apply `k8s/` |
| `validate.ps1` | Compose parse, kustomize render, Helm lint/template, full YAML checks |
| `validate-yaml.py` | PyYAML parse plus cross-file/catalog invariants (called by `validate.ps1`) |
| `kind-config.yaml` | kind cluster with ingress-ready labels and host ports 18080/18443 |
| `_common.ps1` | Tool discovery, Docker engine guard, image catalog |

## Examples

```powershell
pwsh ./scripts/build-images.ps1
pwsh ./scripts/compose-up.ps1 -Build
pwsh ./scripts/compose-down.ps1 -Volumes
pwsh ./scripts/deploy-kind.ps1 -WithIngress
pwsh ./scripts/deploy-minikube.ps1 -Memory 12g
pwsh ./scripts/validate.ps1
```

## Docker engine guard

`build-images.ps1`, `compose-up.ps1`, `deploy-kind.ps1`, and `deploy-minikube.ps1` call
`docker info` first and stop with the WSL2/reboot remediation text when the Linux engine is
unavailable. `validate.ps1` does not need a running engine: compose parsing, kustomize
rendering, and Helm rendering are offline operations.

## Tool discovery

The scripts look on `PATH` first and then at the standard install locations used on this
machine: Docker Desktop (`C:\Program Files\Docker\Docker\resources\bin`), minikube
(`C:\Program Files\Kubernetes\Minikube\minikube.exe`), and common kind/Helm locations.
