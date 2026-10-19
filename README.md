# eia-ops

Operations monorepo: local container images, Compose stack, Kubernetes manifests, Helm chart,
infrastructure, environments, observability, release, and security policy.

- GitHub organization: `eia-open-insurance`
- Repository URL: https://github.com/eia-open-insurance/eia-ops
- Type: Platform product area
- Deployable: No (contains multiple deployable components)

## Components

| Component | Path | Type | Deployable |
|---|---|---|---|
| Container images | `images/` | Deployment-owned Dockerfiles and build contexts | No |
| Compose | `compose/` | Local Docker Compose stack | Yes (local) |
| Kubernetes | `k8s/` | Plain manifests for namespace `eia-local` | Yes (local) |
| Helm | `helm/eia/` | Templated local deployment | Yes (local) |
| Scripts | `scripts/` | Build, up/down, kind/minikube, validation | No |
| Infrastructure | `infra/` | Terraform, Helm, Kubernetes | No |
| Environments | `environments/` | Environment overlays | No |
| Observability | `observability/` | Dashboards, alerts, SLOs | No |
| Release | `release/` | Release scripts and manifests | No |
| Security | `security/` | Threat models, policy, test evidence | No |

## Current blocker

**Docker Desktop / WSL2 requires a Windows reboot on this machine before the Linux engine and
minikube can run.** The assets in this repository are complete and validated offline, but no
image build, `docker compose up`, kind cluster, minikube cluster, or Helm install has been
executed here.

Evidence recorded on 2026-10-19:

| Check | Result |
|---|---|
| `wsl --status` | `WSL_E_WSL_OPTIONAL_COMPONENT_REQUIRED`; "The system may need to be restarted so the changes can take effect." |
| Windows optional features | `Microsoft-Windows-Subsystem-Linux` = Enabled, `VirtualMachinePlatform` = Enabled |
| Pending reboot | `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending` = present |
| `docker info` | HTTP 500 for `//./pipe/dockerDesktopLinuxEngine/v1.56/info` |
| Docker client | v29.8.2 (Compose v5.6.0), engine unavailable |
| `minikube status` | v1.39.0 installed; no profile until the engine can start |

Remediation, performed by the operator:

1. Restart Windows so the WSL2 optional component activates.
2. Start Docker Desktop and wait for "Engine running".
3. Verify the engine and cluster tooling:

```powershell
docker version
docker run --rm hello-world
wsl --status
minikube status
```

Until then, `scripts/validate.ps1` is the supported check: it needs no Docker engine, cluster,
or network access.

## Layout

```text
repos/eia-ops/
  images/            deployment-owned Dockerfiles + build-context table
  compose/           docker-compose.yml, gateway/nginx/initdb configuration, .env.example
  k8s/               namespace, configmaps, secret placeholder, postgres, platform,
                     shell, ingress, verticals/*.yaml, kustomization.yaml
  helm/eia/          Chart.yaml, values.yaml, templates/, files/
  scripts/           build-images, compose-up/down, deploy-kind, deploy-minikube, validate
```

## Prerequisites

| Tool | Version used here | Notes |
|---|---|---|
| JDK | 22 (`C:\Program Files\Eclipse Adoptium\jdk-22.0.2.9-hotspot`) | Every Java repo pins the Java 22 toolchain |
| Gradle | 8.14.3 (wrapper committed) | `scripts/build-images.ps1` calls `gradlew.bat` |
| Docker Desktop | 29.8.2 client / Compose v5.6.0 | Requires the WSL2 reboot above |
| kubectl | v1.36.1 | Shipped with Docker Desktop at `resources\bin` |
| kind | optional | `deploy-kind.ps1` fails clearly when it is absent |
| minikube | v1.39.0 | `C:\Program Files\Kubernetes\Minikube\minikube.exe` |
| Helm | 3.x, optional | Chart validated with Helm 3.16.3; not on `PATH` yet |
| Python | 3.12.8 + PyYAML 6.0.3 | Required by `scripts/validate.ps1` |

The scripts look on `PATH` first, then at the standard install locations listed in
[`scripts/README.md`](scripts/README.md).

## Build images

```powershell
pwsh ./scripts/build-images.ps1
```

This runs `gradlew.bat bootJar -x test` in each owning repository and builds:

- `eia/gateway:local`, `eia/auth:local`, `eia/config:local`, `eia/lineage:local`
- `eia/<vertical>-expert:local` and `eia/<vertical>-domain:local` for all ten verticals
- `eia/shell:local` from the existing `dist/`

Useful switches: `-Tag <tag>`, `-SkipGradle` (reuse jars), `-SkipJava`, `-SkipShell`,
`-BuildFrontend` (run `npm ci` + `npm run build` before packaging the shell).

Build contexts, including why 16 Dockerfiles live here instead of in the owning repositories,
are in [`images/README.md`](images/README.md). Manual example:

```powershell
Set-Location repos/eia-platform
.\gradlew.bat :gateway:bootJar -x test
Set-Location ../..

docker build -f repos/eia-ops/images/platform/gateway.Dockerfile `
  -t eia/gateway:local repos/eia-platform/gateway
```

## Docker Compose

```powershell
Copy-Item compose/.env.example compose/.env   # local values only
pwsh ./scripts/compose-up.ps1
pwsh ./scripts/compose-up.ps1 -Build          # rebuild images first
pwsh ./scripts/compose-down.ps1
pwsh ./scripts/compose-down.ps1 -Volumes      # also delete PostgreSQL data
```

Direct equivalents:

```powershell
docker compose -f compose/docker-compose.yml up -d
docker compose -f compose/docker-compose.yml ps
docker compose -f compose/docker-compose.yml down
```

The stack contains PostgreSQL, the four platform services, the shell, and 20 vertical services
(26 containers). The shell is at <http://localhost:3000>; its nginx `/api` proxy forwards to the
gateway. See [`compose/README.md`](compose/README.md).

## Kubernetes

Plain manifests (namespace `eia-local`, 26 Deployments, 26 Services, 4 ConfigMaps, 1 Secret,
1 PVC, 1 Ingress):

```powershell
kubectl apply -k k8s
kubectl -n eia-local get deploy,svc,pods
kubectl -n eia-local port-forward svc/eia-shell 3000:80
kubectl delete -k k8s
```

kind:

```powershell
pwsh ./scripts/deploy-kind.ps1 -WithIngress
# add "127.0.0.1 eia.local" to the hosts file, then open http://eia.local:18080
kind delete cluster --name eia-local
```

minikube:

```powershell
pwsh ./scripts/deploy-minikube.ps1
minikube ip --profile eia-local    # add "<ip> eia.local" to the hosts file
minikube stop --profile eia-local
```

Both scripts build images, load them into the node, apply `k8s/`, and wait for rollout. Without
an ingress controller, the printed `kubectl port-forward` commands are the entry point. Details:
[`k8s/README.md`](k8s/README.md).

## Helm

```powershell
helm lint helm/eia
helm template eia helm/eia
helm upgrade --install eia helm/eia --namespace eia-local --create-namespace
helm upgrade --install eia helm/eia --namespace eia-local `
  --set global.imageTag=local `
  --set postgres.auth.password='<local-password>'
helm uninstall eia --namespace eia-local
```

Values expose every image tag and service port (`global.imageTag`, per-service
`image.repository`/`image.tag`, `platform.*.port`, `verticals.*.{expert,domain}.port`,
`shell.port`, `postgres.servicePort`). See [`helm/eia/README.md`](helm/eia/README.md).

## Service ports and health endpoints

Every Java service exposes Spring Boot Actuator at `/actuator/health` (and `/actuator/info`).
The shell exposes nginx `/healthz`.

| Service | Port | Health |
|---|---:|---|
| Gateway | 8080 | `/actuator/health` |
| Auth | 9000 | `/actuator/health` |
| Config | 8888 | `/actuator/health` |
| Lineage | 8101 | `/actuator/health` |
| Shell | 80 (Compose host 3000) | `/healthz` |
| Party expert / domain | 8081 / 8082 | `/actuator/health` |
| Policy expert / domain | 8083 / 8084 | `/actuator/health` |
| Contract expert / domain | 8085 / 8086 | `/actuator/health` |
| Direct claims expert / domain | 8087 / 8088 | `/actuator/health` |
| Assumed claims expert / domain | 8089 / 8090 | `/actuator/health` |
| Cession expert / domain | 8091 / 8092 | `/actuator/health` |
| Retrocession expert / domain | 8093 / 8094 | `/actuator/health` |
| Document expert / domain | 8095 / 8096 | `/actuator/health` |
| Payment expert / domain | 8097 / 8098 | `/actuator/health` |
| Notifications expert / domain | 8099 / 8100 | `/actuator/health` |
| PostgreSQL | 5432 | `pg_isready` |

The databases are `eia_party`, `eia_policy`, `eia_contract`, `eia_direct`, `eia_assumed`,
`eia_cession`, `eia_retrocession`, `eia_document`, `eia_payment`, and `eia_notifications`.

## Validation

```powershell
pwsh ./scripts/validate.ps1
```

The script runs these checks without a Docker engine or cluster:

1. `docker compose config --quiet`
2. `kubectl kustomize k8s`
3. `helm lint helm/eia` and `helm template eia helm/eia` (when Helm is installed)
4. `python scripts/validate-yaml.py`: PyYAML parse of every YAML file (duplicate keys rejected,
   merge keys resolved), plus cross-file invariants for Compose, Dockerfiles, Kubernetes, and
   Helm; optionally parses the rendered kustomize and Helm output.

Last recorded run (2026-10-19, before the Docker engine blocker was cleared):

```text
docker compose config ......... OK
kubectl kustomize ............. 60 objects
helm lint ..................... 1 chart linted, 0 failed
helm template ................. 60 objects
YAML parse .................... 27 files, 70 documents (PyYAML 6.0.3)
Dockerfiles ................... 16 deployment-owned + 9 owning-repository files OK
Compose catalog ............... 26 services, ports/build contexts OK
Kubernetes .................... 26 Deployments, 26 Services, probes/Secrets/Ingress OK
Helm .......................... ports, tags, files, 8 templates OK
Rendered output ............... kustomize 60 objects, helm 59 objects; probes and ports OK
RESULT: PASS - 41 checks
```

Kubernetes probes are defined for every Deployment: HTTP `/actuator/health` for Java services,
`pg_isready` for PostgreSQL, and `/healthz` for the shell. The manifests also set resource
requests/limits, non-root Java pods, read-only root filesystems, and a `/tmp` emptyDir.

## Secrets

- No real credential is committed.
- Compose reads `POSTGRES_USER` / `POSTGRES_PASSWORD` from `compose/.env`; `.env` is ignored and
  `.env.example` is the committed local-only template.
- `k8s/02-secret.yaml` and the Helm default create `eia-db` with
  `POSTGRES_PASSWORD: replace-me-local-only`. `scripts/validate-yaml.py` asserts that this stays
  a placeholder.
- For anything shared or non-local, override `--set postgres.auth.password`, supply
  `postgres.auth.existingSecret`, or replace the Secret out of band. Secret management and
  90-day rotation are required by SPEC section 14.12.3.

## Scope and known limitations

- The ten vertical **web remotes** are static front-ends and are not part of this stack. Run them
  with `npm start` in each `eia-<vertical>-web` repository (ports 3001-3010); the shell bundle
  contains build-time `localhost:3001-3010` remote URLs from `eia-frontend/shell/webpack.config.js`.
  Serving the federated UI entirely from a cluster requires rebuilding that bundle with cluster
  URLs, which is an application-repository change outside this task.
- The auth service still advertises `http://localhost:9000` as its issuer and uses an in-memory
  user/client registry (application code, not deployment configuration).
- Local only: single PostgreSQL replica, no backup/PITR, no TLS/mTLS, no blue/green or canary.
  SPEC section 17.2 deployment patterns and the 17.10 production readiness gates are not
  evidenced by this stack.
- No hosted CI. Every build, deployment, and validation step is run locally.

## Verification

Run the project baseline check from the repository root:

```powershell
pwsh ../verify.ps1
```

No hosted CI is used. Component builds and tests run locally.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
