# eia Helm chart

Single-cluster local deployment of the platform, shell, PostgreSQL, and the 20 implemented
vertical services.

## Commands

```powershell
helm lint helm/eia
helm template eia helm/eia
helm upgrade --install eia helm/eia --namespace eia-local --create-namespace
```

Override the image tag, credentials, or host:

```powershell
helm upgrade --install eia helm/eia --namespace eia-local `
  --set global.imageTag=local `
  --set postgres.auth.password='<local-password>' `
  --set ingress.host=eia.local
```

Use an existing Secret instead of the chart's placeholder:

```powershell
helm upgrade --install eia helm/eia --namespace eia-local `
  --set postgres.auth.existingSecret=eia-db
```

## Values

- `global.imageTag` and per-service `image.tag` / `image.repository` for image tags.
- `platform.<name>.port`, `verticals.<vertical>.{expert,domain}.port`, `shell.port`,
  `postgres.servicePort` for service ports.
- `postgres.auth` for local credentials; the placeholder is created only when
  `existingSecret` is empty.
- `ingress.*` for the host and annotations.
- `resources`, `replicaCount`, and `global.javaToolOptions` for sizing.

The chart renders the same workload set as `k8s/`: 26 Deployments, 26 Services, 4 ConfigMaps,
1 Secret, 1 PVC, and 1 Ingress. The Namespace is created by `--create-namespace` and is not a
chart resource, which avoids Helm ownership conflicts on reinstall.

## Notes

- The chart is local-only: single PostgreSQL replica, no TLS, placeholder Secret.
- It renders the same gateway, Config Server, nginx, and initdb payloads as Compose; the
  copies live in `files/` and are checked for equality by `scripts/validate-yaml.py`.
- This is not evidence for the production readiness gates in SPEC section 17.10.
