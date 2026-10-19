# eia-ops

Operations monorepo: infrastructure, environments, observability, release, and security policy.

- GitHub organization: `eia-open-insurance`
- Repository URL: https://github.com/eia-open-insurance/eia-ops
- Type: Platform product area
- Deployable: No (contains multiple deployable components)

## Components

| Component | Path | Type | Deployable |
|---|---|---|---|
| Infrastructure | `infra/` | Terraform, Helm, Kubernetes | No |
| Environments | `environments/` | Environment overlays | No |
| Observability | `observability/` | Dashboards, alerts, SLOs | No |
| Release | `release/` | Release scripts and manifests | No |
| Security | `security/` | Threat models, policy, test evidence | No |

## Verification

Run the project baseline check from the repository root:

```powershell
pwsh ../verify.ps1
```

No hosted CI is used. Component builds and tests run locally.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
