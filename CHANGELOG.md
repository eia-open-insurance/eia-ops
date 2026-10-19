# Changelog

## [Unreleased]

### Added

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
