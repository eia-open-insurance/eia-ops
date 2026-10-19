# Kubernetes manifests (local)

Plain manifests for a single-node local cluster. Namespace: `eia-local`.
Helm is the templated alternative in [`../helm/eia`](../helm/eia/README.md).

## Contents

| File | Objects |
|---|---|
| `00-namespace.yaml` | Namespace `eia-local` |
| `01-configmap.yaml` | Gateway routes/CORS, Config Server placeholder, shell nginx config |
| `02-secret.yaml` | `eia-db` placeholder Secret (local only) |
| `10-postgres.yaml` | Init script ConfigMap, 1Gi PVC, PostgreSQL Deployment, Service |
| `20-platform.yaml` | gateway, auth, config, lineage Deployments and Services |
| `30-shell.yaml` | Shell Deployment and Service |
| `31-web.yaml` | Ten federated web-remote Deployments and Services (`eia-<vertical>-web`, port 80) |
| `36-fsri-simulator.yaml` | FS-RI simulator `eia-fsri-simulator` Deployment and Service (port 8181) |
| `90-ingress.yaml` | Ingress `eia` (`/api`, `/`) and Ingress `eia-remotes` (`/remotes/<vertical>` with nginx rewrite) |
| `verticals/<vertical>.yaml` | Expert + domain Deployments and Services per vertical |
| `kustomization.yaml` | Aggregates all of the above |

## Apply

```powershell
kubectl apply -k k8s
kubectl -n eia-local get deploy,svc,pods
kubectl -n eia-local wait --for=condition=available deployment --all --timeout=900s
```

Images are expected to be loaded into the node as `eia/<service>:local`; every Deployment
sets `imagePullPolicy: IfNotPresent`. Use `scripts/deploy-kind.ps1` or
`scripts/deploy-minikube.ps1` to build, load, and apply in one step.

## Runtime wiring

- **Probes**: Java services use Spring Boot Actuator `/actuator/health` for startup,
  readiness, and liveness. PostgreSQL uses `pg_isready`. The shell uses nginx `/healthz`.
- **Gateway**: mounts `eia-gateway-config` at `/app/config/application.yml`, overriding the
  localhost targets that ship inside the gateway jar with Kubernetes Service names.
- **Database**: one PostgreSQL pod; the init ConfigMap creates `eia_party`, `eia_policy`,
  `eia_contract`, `eia_direct`, `eia_assumed`, `eia_cession`, `eia_retrocession`,
  `eia_document`, `eia_payment`, and `eia_notifications`.
- **Storage**: the PVC omits `storageClassName` and uses the cluster default. If the cluster
  has no default StorageClass (or for kind/minikube with a specific class), set
  `storageClassName` explicitly in `10-postgres.yaml`.
- **Ingress**: requires an ingress controller. kind users can pass `-WithIngress` to
  `deploy-kind.ps1`; minikube users get it from `minikube addons enable ingress`.
  Without a controller the Ingress is inert, so use `kubectl port-forward`.
- **Federated UI**: the shell bundle loads each remote from the relative path
  `/remotes/<vertical>/remoteEntry.js`. Ingress `eia-remotes` matches
  `/remotes/<vertical>(/|$)(.*)`, uses `nginx.ingress.kubernetes.io/use-regex: "true"` and
  rewrites to `/$2`, so the entry and every chunk are served from the remote's nginx root.
  The shell nginx config applies the same rewrite for `kubectl port-forward svc/eia-shell`
  and Compose. Webpack's automatic public path keeps the browser base at
  `/remotes/<vertical>/`.
- **FS-RI simulator**: `eia-fsri-simulator` runs the eia-quality test double on port 8181.
  The cession-domain and retrocession-domain Deployments set
  `EIA_FSRI_BASE_URL=http://eia-fsri-simulator:8181`; the hand-off path stays
  `/sim/fsri/v1/cessions` and `/sim/fsri/v1/retros` (application defaults).

## Teardown

```powershell
kubectl delete -k k8s
```

This leaves the namespace and PVC in place. Delete them explicitly to remove local data:

```powershell
kubectl delete namespace eia-local
```
