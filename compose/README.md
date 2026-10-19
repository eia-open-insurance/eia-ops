# Compose stack (local)

`docker-compose.yml` starts PostgreSQL, the four platform services, the shell, the
20 implemented vertical services (10 experts + 10 domains), the ten federated web remotes,
and the FS-RI simulator test double in namespace-like DNS names that match the Kubernetes
manifests.

## Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | The stack |
| `.env.example` | Local credentials and image tag; copy to `.env` |
| `config/gateway/application.yml` | Gateway routes to Compose service names; mounted into the gateway |
| `config/server/application.yml` | Placeholder served by the native Config Server |
| `nginx/default.conf` | Shell SPA fallback, `/healthz`, `/api` proxy to the gateway, and `/remotes/<vertical>/` rewrites to the web remotes |
| `initdb/01-create-databases.sh` | Creates the ten `eia_*` databases on first start |

## Use

```powershell
Copy-Item .env.example .env
pwsh ../scripts/compose-up.ps1
pwsh ../scripts/compose-up.ps1 -Build   # rebuild images first
pwsh ../scripts/compose-down.ps1
```

Direct Compose equivalents:

```powershell
docker compose -f compose/docker-compose.yml up -d
docker compose -f compose/docker-compose.yml ps
docker compose -f compose/docker-compose.yml down -v
```

## Ports

| Service | Host port |
|---|---:|
| Shell (`/`, `/api` proxy) | 3000 |
| Gateway | 8080 |
| Auth | 9000 |
| Config | 8888 |
| Lineage | 8101 |
| Party expert / domain | 8081 / 8082 |
| Policy expert / domain | 8083 / 8084 |
| Contract expert / domain | 8085 / 8086 |
| Direct claims expert / domain | 8087 / 8088 |
| Assumed claims expert / domain | 8089 / 8090 |
| Cession expert / domain | 8091 / 8092 |
| Retrocession expert / domain | 8093 / 8094 |
| Document expert / domain | 8095 / 8096 |
| Payment expert / domain | 8097 / 8098 |
| Notifications expert / domain | 8099 / 8100 |
| Party web … Notifications web (federated remotes) | 3001 … 3010 |
| FS-RI simulator | 8181 |
| PostgreSQL | 5432 |

Compose does not health-check the Java images (the JRE image has no HTTP client). Ordering is
explicit: experts wait for a healthy PostgreSQL, domains wait for their expert and the FS-RI
simulator, and the shell waits for the gateway and the ten web remotes. Kubernetes probes
provide the full health model.
