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
| `90-ingress.yaml` | Ingress `eia.local` (`/api` to gateway, `/` to shell) |
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

## Teardown

```powershell
kubectl delete -k k8s
```

This leaves the namespace and PVC in place. Delete them explicitly to remove local data:

```powershell
kubectl delete namespace eia-local
```
