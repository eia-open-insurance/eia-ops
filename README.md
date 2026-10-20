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

## Local stack status

The Docker Desktop Linux engine and the minikube profile `minikube` are running, and the
in-cluster stack has been deployed from `k8s/`. Recorded 2026-10-20 after adding event-ingest,
the outbox wiring, and the web remotes:

| Check | Result |
|---|---|
| `docker version` | server 29.9.1 |
| `minikube profile list` | profile `minikube`, driver docker, v1.37.0, Running |
| Pods in `eia-local` | 38/38 Running and Ready (includes `eia-event-ingest`) |
| Gateway smoke | 10/10 `/api/v1/*` routes HTTP 200; `/api/v1/events/{stats,recent}` HTTP 200 |
| Federated UI | Playwright `tests/live-all.spec.js` with `EIA_LIVE=1`: 11/11 through `kubectl port-forward svc/eia-shell 3000:80` |
| FS-RI hand-off | cession `CES-000000001`: OPEN → RULE_APPLIED → `HANDED_OFF`, `fsriStatus=POSTED`, `FSRI-CES-DIRECT-000001` |
| Outbox -> inbox | party `PTY-000000004` event `5bd6b801-6dca-540c-ab3f-2301e3527214`: outbox PUBLISHED, inbox PROCESSED, `signatureVerified=true` |
| `scripts/validate.ps1` | PASS, 50 checks |

The earlier blocker (the WSL2 optional component required a Windows restart before Docker
Desktop's Linux engine and minikube could run) is resolved; the remediation was the recorded
Windows restart followed by a Docker Desktop start.

## Layout

```text
repos/eia-ops/
  images/            deployment-owned Dockerfiles (platform, verticals, web, simulators)
                     plus the build-context table
  compose/           docker-compose.yml, gateway/nginx/initdb configuration, .env.example
  k8s/               namespace, configmaps, secret placeholder, postgres, platform,
                     shell, web remotes, FS-RI simulator, ingress, verticals/*.yaml,
                     kustomization.yaml
  helm/eia/          Chart.yaml, values.yaml, templates/, files/
  scripts/           build-images, compose-up/down, deploy-kind, deploy-minikube, validate
```

## Prerequisites

| Tool | Version used here | Notes |
|---|---|---|
| JDK | 22 (`C:\Program Files\Eclipse Adoptium\jdk-22.0.2.9-hotspot`) | Every Java repo pins the Java 22 toolchain |
| Gradle | 8.14.3 (wrapper committed) | `scripts/build-images.ps1` calls `gradlew.bat` |
| Docker Desktop | 29.9.1 server / Compose v5.6.0 | Linux engine running (WSL2 active) |
| kubectl | v1.36.1 | Shipped with Docker Desktop at `resources\bin` |
| kind | optional | `deploy-kind.ps1` fails clearly when it is absent |
| minikube | v1.39.0 (node v1.37.0) | Profile `minikube`, driver docker, running |
| Helm | 4.3.1 | On `PATH`; `validate.ps1` runs `helm lint` and `helm template` |
| Python | 3.12.8 + PyYAML 6.0.3 | Required by `scripts/validate.ps1` |

The scripts look on `PATH` first, then at the standard install locations listed in
[`scripts/README.md`](scripts/README.md).

## Build images

```powershell
pwsh ./scripts/build-images.ps1
```

This runs `gradlew.bat bootJar -x test` in each owning repository and builds:

- `eia/gateway:local`, `eia/auth:local`, `eia/config:local`, `eia/lineage:local`,
  `eia/event-ingest:local`
- `eia/<vertical>-expert:local` and `eia/<vertical>-domain:local` for all ten verticals
- `eia/<vertical>-web:local` for the ten federated web remotes (from each web repo's `dist/`)
- `eia/fsri-simulator:local` for the FS-RI test double (from `repos/eia-quality`)
- `eia/shell:local` from the existing `dist/`

Useful switches: `-Tag <tag>`, `-SkipGradle` (reuse jars), `-SkipJava`, `-SkipShell`,
`-SkipWeb`, `-SkipSimulators`, `-BuildFrontend` (run `npm ci` + `npm run build` in the shell
and in every web-remote repository before packaging).

Build contexts, including why the Java Dockerfiles live here instead of in the owning
repositories, are in [`images/README.md`](images/README.md). Manual example:

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

The stack contains PostgreSQL, the five platform services, the shell, 20 vertical services,
the ten federated web remotes, and the FS-RI simulator (38 containers). The shell is at
<http://localhost:3000>; its nginx `/api` proxy forwards to the gateway and its
`/remotes/<vertical>/` proxies forward to the web remotes. See
[`compose/README.md`](compose/README.md).

## Kubernetes

Plain manifests (namespace `eia-local`, 38 Deployments, 38 Services, 4 ConfigMaps,
2 Secrets, 1 PVC, 2 Ingresses, 1 NetworkPolicy):

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
`web.*.port`, `simulators.fsri.port`, `shell.port`, `postgres.servicePort`). See
[`helm/eia/README.md`](helm/eia/README.md).

## Service ports and health endpoints

Every Java service exposes Spring Boot Actuator at `/actuator/health` (and `/actuator/info`).
The shell exposes nginx `/healthz`.

| Service | Port | Health |
|---|---:|---|
| Gateway | 8080 | `/actuator/health` |
| Auth | 9000 | `/actuator/health` |
| Config | 8888 | `/actuator/health` |
| Lineage | 8101 | `/actuator/health` |
| Event ingest | 8102 | `/actuator/health` |
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
| Web remotes (`eia-<vertical>-web`) | 80 (Compose host 3001-3010) | `/healthz` |
| FS-RI simulator | 8181 | `/sim/fsri/health` |
| PostgreSQL | 5432 | `pg_isready` |

The databases are `eia_party`, `eia_policy`, `eia_contract`, `eia_direct`, `eia_assumed`,
`eia_cession`, `eia_retrocession`, `eia_document`, `eia_payment`, `eia_notifications`, and
`eia_platform` (event ingest inbox). All ten expert Deployments enable the transactional outbox
with `EIA_OUTBOX_ENDPOINT=http://eia-event-ingest:8102/internal/events` and the shared
`eia-event-signing` Secret; `/internal/events` is cluster-only (no Ingress path, NetworkPolicy
on port 8102).

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

Recorded after the event-ingest service and outbox wiring were added (2026-10-20):

```text
docker compose config ......... OK
kubectl kustomize ............. 87 objects
helm lint ..................... 1 chart linted, 0 failed
helm template ................. 86 objects
YAML parse .................... 30 files, 97 documents (PyYAML 6.0.3)
Dockerfiles ................... 17 deployment Java + web-remote + FS-RI simulator + 9 owning-repository files OK
Compose catalog ............... 38 services, ports/build contexts/FS-RI/outbox wiring OK
Kubernetes .................... 38 Deployments, 38 Services, 2 Secrets, NetworkPolicy, Ingress OK
Helm .......................... ports, tags, files, 12 templates OK
Rendered output ............... kustomize 87 objects, helm 86 objects; probes and ports OK
RESULT: PASS - 50 checks
```

Kubernetes probes are defined for every Deployment: HTTP `/actuator/health` for Java services,
`/healthz` for the shell and web remotes, `/sim/fsri/health` for the FS-RI simulator, and
`pg_isready` for PostgreSQL. The manifests also set resource requests/limits, non-root Java
pods, read-only root filesystems, and a `/tmp` emptyDir.

## Secrets

- No real credential is committed.
- Compose reads `POSTGRES_USER` / `POSTGRES_PASSWORD` from `compose/.env`; `.env` is ignored and
  `.env.example` is the committed local-only template.
- `k8s/02-secret.yaml` and the Helm default create `eia-db` with
  `POSTGRES_PASSWORD: replace-me-local-only`, plus `eia-event-signing` with a placeholder
  `EIA_EVENT_SIGNING_SECRET` for outbox HMAC delivery. `scripts/validate-yaml.py` asserts that
  both stay placeholders.
- For anything shared or non-local, override `--set postgres.auth.password`, supply
  `postgres.auth.existingSecret`, or replace the Secret out of band. Secret management and
  90-day rotation are required by SPEC section 14.12.3.

## Scope and known limitations

- The ten federated **web remotes** are deployed by this stack: `eia/<vertical>-web:local`,
  served on port 80, routed by Ingress `eia-remotes` at `/remotes/<vertical>(/|$)(.*)` with an
  nginx rewrite, and proxied identically by the shell nginx for `kubectl port-forward` and
  Compose. The shell bundle consumes relative `/remotes/<vertical>/remoteEntry.js` URLs. This
  is still a **build-time Module Federation remote map**, not the signed runtime manifest of
  SPEC 5.3/5.4: no manifest signature, SRI, canary/killSwitch, or fallback version is
  implemented.
- The **FS-RI simulator** is the eia-quality test double (SPEC 15.3), not the production SAP
  FS-RI adapter. Cession-domain and retrocession-domain reach it at
  `http://eia-fsri-simulator:8181`; the simulator is single-replica and in-memory, so its
  records reset on pod restart.
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
