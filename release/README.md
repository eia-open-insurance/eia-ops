# eia-ops/release

- GitHub organization: `eia-open-insurance`
- Repository URL: https://github.com/eia-open-insurance/eia-ops/tree/main/release
- Type: Release
- Deployable: No
- Owner: Platform
- Runtime: Release scripts and YAML
- Data store: Not applicable
- Depends on: eia-ops/infra, eia-ops/environments, eia-contracts

## Purpose

Release orchestration, version manifest, promotion, and rollback automation.

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

Owns the release manifest and evidence links.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
