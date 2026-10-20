# eia Helm chart

Single-cluster local deployment of the platform (including event ingest), shell, PostgreSQL,
the 20 implemented vertical services, the ten federated web remotes, and the FS-RI simulator
test double.

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
  `web.<vertical>.port`, `simulators.fsri.port`, and `postgres.servicePort` for service ports.
- `verticals.cession.domain.fsriBaseUrl` and `verticals.retrocession.domain.fsriBaseUrl`
  set `EIA_FSRI_BASE_URL` for the two reinsurance-administration domains.
- `verticals.party.domain.database` and `verticals.policy.domain.database` enable the
  `EIA_<VERTICAL>_DB_*` read-model datasource env for the two search-enabled domains;
  credentials come from the same `eia-db` Secret.
- `postgres.auth` for local credentials; the placeholder is created only when
  `existingSecret` is empty.
- `eventSigning.secret` (or `eventSigning.existingSecret`) is the shared HMAC secret used by
  the ten expert outboxes and `eia-event-ingest`; `platform.event-ingest.database` defaults to
  `eia_platform`.
- `ingress.*` for the host, annotations, and the `/remotes` prefix used by the
  second Ingress (`eia-remotes`) whose regex rewrite strips the prefix.
- `resources`, `replicaCount`, and `global.javaToolOptions` for sizing.

The chart renders the same workload set as `k8s/`: 38 Deployments, 38 Services, 4 ConfigMaps,
2 Secrets, 1 PVC, 2 Ingresses, and 1 NetworkPolicy. The Namespace is created by
`--create-namespace` and is not a chart resource, which avoids Helm ownership conflicts on
reinstall.

## Notes

- The chart is local-only: single PostgreSQL replica, no TLS, placeholder Secret.
- It renders the same gateway, Config Server, nginx, and initdb payloads as Compose; the
  copies live in `files/` and are checked for equality by `scripts/validate-yaml.py`.
- This is not evidence for the production readiness gates in SPEC section 17.10.
