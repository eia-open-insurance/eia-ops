# Deployment-owned container images

The component repositories keep their own Dockerfiles. This directory holds corrected
Dockerfiles used by the local build scripts, because the owning files cannot be edited from
`eia-ops` and several of them do not match the actual Gradle output:

- `eia-platform/{gateway,auth,config,lineage}/Dockerfile` copy `target/*.jar`, but the Gradle
  build writes `build/libs/*-SNAPSHOT.jar`; `auth`, `config`, and `lineage` also `EXPOSE 8080`
  instead of their real ports (`9000`, `8888`, `8101`).
- Six verticals (`assumed-claims`, `contract`, `direct-claims`, `party`, `retrocession`)
  copy `target/*.jar` and expose `8080` on both tiers instead of their real ports.
- `eia-document-{domain,expert}/Dockerfile` use `build/libs/*.jar`, which matches both the
  Spring Boot jar and the `-plain.jar`; `COPY` fails when it matches more than one file.

The eight remaining Java Dockerfiles (`policy`, `cession`, `notifications`, `payment`)
already copy the correct Gradle boot jar and expose the correct port, so they are used
unchanged. The shell image also uses its repository Dockerfile. The ten web remotes and the
FS-RI simulator likewise use deployment-owned Dockerfiles from this directory (see the two
sections below).

## Build contexts

All contexts are component directories relative to the workspace root (the parent of `repos/`).
The context must be the component directory, because each Dockerfile copies `build/libs/`.

| Image | Build context | Dockerfile | Port |
|---|---|---|---:|
| `eia/gateway:local` | `repos/eia-platform/gateway` | `repos/eia-ops/images/platform/gateway.Dockerfile` | 8080 |
| `eia/auth:local` | `repos/eia-platform/auth` | `repos/eia-ops/images/platform/auth.Dockerfile` | 9000 |
| `eia/config:local` | `repos/eia-platform/config` | `repos/eia-ops/images/platform/config.Dockerfile` | 8888 |
| `eia/lineage:local` | `repos/eia-platform/lineage` | `repos/eia-ops/images/platform/lineage.Dockerfile` | 8101 |
| `eia/party-expert:local` | `repos/eia-party-expert` | `repos/eia-ops/images/verticals/party-expert.Dockerfile` | 8081 |
| `eia/party-domain:local` | `repos/eia-party-domain` | `repos/eia-ops/images/verticals/party-domain.Dockerfile` | 8082 |
| `eia/policy-expert:local` | `repos/eia-policy-expert` | `repos/eia-policy-expert/Dockerfile` | 8083 |
| `eia/policy-domain:local` | `repos/eia-policy-domain` | `repos/eia-policy-domain/Dockerfile` | 8084 |
| `eia/contract-expert:local` | `repos/eia-contract-expert` | `repos/eia-ops/images/verticals/contract-expert.Dockerfile` | 8085 |
| `eia/contract-domain:local` | `repos/eia-contract-domain` | `repos/eia-ops/images/verticals/contract-domain.Dockerfile` | 8086 |
| `eia/direct-claims-expert:local` | `repos/eia-direct-claims-expert` | `repos/eia-ops/images/verticals/direct-claims-expert.Dockerfile` | 8087 |
| `eia/direct-claims-domain:local` | `repos/eia-direct-claims-domain` | `repos/eia-ops/images/verticals/direct-claims-domain.Dockerfile` | 8088 |
| `eia/assumed-claims-expert:local` | `repos/eia-assumed-claims-expert` | `repos/eia-ops/images/verticals/assumed-claims-expert.Dockerfile` | 8089 |
| `eia/assumed-claims-domain:local` | `repos/eia-assumed-claims-domain` | `repos/eia-ops/images/verticals/assumed-claims-domain.Dockerfile` | 8090 |
| `eia/cession-expert:local` | `repos/eia-cession-expert` | `repos/eia-cession-expert/Dockerfile` | 8091 |
| `eia/cession-domain:local` | `repos/eia-cession-domain` | `repos/eia-cession-domain/Dockerfile` | 8092 |
| `eia/retrocession-expert:local` | `repos/eia-retrocession-expert` | `repos/eia-ops/images/verticals/retrocession-expert.Dockerfile` | 8093 |
| `eia/retrocession-domain:local` | `repos/eia-retrocession-domain` | `repos/eia-ops/images/verticals/retrocession-domain.Dockerfile` | 8094 |
| `eia/document-expert:local` | `repos/eia-document-expert` | `repos/eia-ops/images/verticals/document-expert.Dockerfile` | 8095 |
| `eia/document-domain:local` | `repos/eia-document-domain` | `repos/eia-ops/images/verticals/document-domain.Dockerfile` | 8096 |
| `eia/payment-expert:local` | `repos/eia-payment-expert` | `repos/eia-payment-expert/Dockerfile` | 8097 |
| `eia/payment-domain:local` | `repos/eia-payment-domain` | `repos/eia-payment-domain/Dockerfile` | 8098 |
| `eia/notifications-expert:local` | `repos/eia-notifications-expert` | `repos/eia-notifications-expert/Dockerfile` | 8099 |
| `eia/notifications-domain:local` | `repos/eia-notifications-domain` | `repos/eia-notifications-domain/Dockerfile` | 8100 |
| `eia/shell:local` | `repos/eia-frontend/shell` | `repos/eia-frontend/shell/Dockerfile` | 80 |
| `eia/<vertical>-web:local` | `repos/eia-<vertical>-web` | `repos/eia-ops/images/web/remote.Dockerfile` | 80 |
| `eia/fsri-simulator:local` | `repos/eia-quality` | `repos/eia-ops/images/simulators/fsri.Dockerfile` | 8181 |

PostgreSQL uses the upstream `postgres:17-alpine` image.

## Web remote images

The ten federated remotes share one deployment-owned Dockerfile,
`web/remote.Dockerfile`. It copies the owning repository's `dist/` bundle into
`nginx:1.27-alpine` and writes an nginx config that:

- serves the bundle at `/` with `try_files $uri $uri/ /index.html` (SPA fallback);
- exposes `/healthz` for Kubernetes probes;
- marks `remoteEntry.js` `no-store` and content chunks immutable.

The build context is the web repository (not this directory), so the bundle must be built
first:

```powershell
Set-Location repos/eia-party-web
npm ci
npm run build
Set-Location ../..
docker build -f repos/eia-ops/images/web/remote.Dockerfile -t eia/party-web:local repos/eia-party-web
```

Neither the Ingress rewrite (`/remotes/<vertical>(/|$)(.*)` → `/$2`) nor the shell nginx
proxy (`/remotes/<vertical>/` → `http://eia-<vertical>-web:80/`) changes the bundle: Webpack's
automatic public path derives the chunk base from the executed `remoteEntry.js` URL, so the
same image works behind the Ingress, behind the shell port-forward, and in Compose.

## FS-RI simulator image

`simulators/fsri.Dockerfile` packages the eia-quality FS-RI test double (SPEC 15.3). The
build context is `repos/eia-quality` because the simulator imports
`simulators/common/*.mjs`; no npm install is needed (Node built-ins only). The owning
Dockerfile exposes 8080, while this image keeps the simulator's native port **8181** so that
the Service, `EIA_FSRI_BASE_URL=http://eia-fsri-simulator:8181`, and the local
`run-local.ps1` workflow all agree.

## Manual build example

```powershell
# 1. Build the boot jar in the owning repository
Set-Location repos/eia-platform
.\gradlew.bat :gateway:bootJar -x test
Set-Location ../..

# 2. Build the image with the deployment-owned Dockerfile
docker build -f repos/eia-ops/images/platform/gateway.Dockerfile -t eia/gateway:local repos/eia-platform/gateway
```

`scripts/build-images.ps1` runs both steps for every image.
