# Changelog

## [Unreleased]

### Added

- `eia-event-ingest` Deployment/Service (8102), `eia-event-signing` Secret, and a
  cluster-only NetworkPolicy for `/internal/events`.
- Outbox wiring on all ten expert Deployments (`EIA_OUTBOX_ENABLED`,
  `EIA_OUTBOX_ENDPOINT=http://eia-event-ingest:8102/internal/events`, shared signing secret).
- `eia_platform` database in the Compose, Kubernetes, and Helm PostgreSQL init scripts.
- Gateway route `/api/v1/events/**`, Helm values/filters for event ingest, and
  deployment-owned `images/platform/event-ingest.Dockerfile`.
- `scripts/validate-yaml.py` checks for outbox wiring, the event-ingest Secret, and NetworkPolicy.
- Local deployment assets for the implemented platform and vertical services:
  - `images/` deployment-owned Dockerfiles for Gradle outputs and documented build contexts
  - `compose/docker-compose.yml` with PostgreSQL, gateway, auth, config, lineage, shell, and 20 vertical services
  - `k8s/` manifests for namespace `eia-local` (Deployments, Services, ConfigMaps, Secret placeholder, PVC, Ingress, probes)
  - `helm/eia` chart with image-tag and service-port values
  - `scripts/` for image build, Compose up/down, kind and minikube deployment, and offline validation
- `scripts/validate-yaml.py` cross-checks YAML parse, duplicate keys, Compose catalog, Dockerfiles, Kubernetes objects, Helm values, and rendered output.

### Fixed

- Corrected Dockerfile assumptions for Gradle outputs (`target/*.jar` to `build/libs/*-SNAPSHOT.jar`) and service ports without editing the owning application repositories.

## [0.1.0] - 2026-10-19

### Added

- Consolidated repository baseline.
