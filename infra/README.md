# eia-ops/infra

- GitHub organization: `eia-open-insurance`
- Repository URL: https://github.com/eia-open-insurance/eia-ops/tree/main/infra
- Type: Infrastructure
- Deployable: No
- Owner: SRE
- Runtime: Terraform and Helm
- Data store: Cloud infrastructure
- Depends on: eia-ops/environments

## Purpose

Terraform, Kubernetes, Helm, network, database, storage, and cloud infrastructure.

## Responsibilities

- Keep this repository focused on one deployable component or one platform concern.
- Follow the repository standard in `../CONVENTIONS.md` and the specification in `../../SPEC.md`.
- Publish and consume contracts through `eia-contracts`.
- Maintain README, CODEOWNERS, SECURITY, CHANGELOG, tests, and local verification.
- Contain no business logic in shared libraries or front-end remotes.

## Verification

- Lint and format
- Unit tests with 100% business-logic coverage where applicable
- Contract tests
- Integration or Playwright tests where applicable
- Security scan and SBOM
- Build and publish

## Notes

Environment-agnostic modules.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
