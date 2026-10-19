# eia-ops/security

- GitHub organization: `eia-open-insurance`
- Repository URL: https://github.com/eia-open-insurance/eia-ops/tree/main/security
- Type: Security
- Deployable: No
- Owner: Security
- Runtime: Policy-as-code and scripts
- Data store: Not applicable
- Depends on: eia-contracts, eia-ops/infra

## Purpose

Threat models, security test harnesses, penetration-test evidence, and policy-as-code.

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

No production secrets.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
