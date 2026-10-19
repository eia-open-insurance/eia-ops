#!/usr/bin/env python3
"""Parse and cross-check the eia-ops deployment YAML.

The workspace already ships PyYAML 6.0.3, so no extra package install is required.
Checks cover YAML syntax (including duplicate keys and merge keys), the Compose
service/port/build-context map, the Kubernetes object set and probes, the Helm
values/files/template structure, and optionally the rendered kustomize and Helm output.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import yaml

NAMESPACE = "eia-local"
JAVA_OPTS = "-Xms32m -Xmx256m -XX:+UseSerialGC"

PLATFORM = {
    "gateway": 8080,
    "auth": 9000,
    "config": 8888,
    "lineage": 8101,
}

VERTICALS = {
    "party": {"expert": 8081, "domain": 8082, "database": "eia_party"},
    "policy": {"expert": 8083, "domain": 8084, "database": "eia_policy"},
    "contract": {"expert": 8085, "domain": 8086, "database": "eia_contract"},
    "direct-claims": {"expert": 8087, "domain": 8088, "database": "eia_direct"},
    "assumed-claims": {"expert": 8089, "domain": 8090, "database": "eia_assumed"},
    "cession": {"expert": 8091, "domain": 8092, "database": "eia_cession"},
    "retrocession": {"expert": 8093, "domain": 8094, "database": "eia_retrocession"},
    "document": {"expert": 8095, "domain": 8096, "database": "eia_document"},
    "payment": {"expert": 8097, "domain": 8098, "database": "eia_payment"},
    "notifications": {"expert": 8099, "domain": 8100, "database": "eia_notifications"},
}

SHELL_PORT = 80
SHELL_HOST_PORT = 3000
POSTGRES_PORT = 5432

OPS_DOCKERFILES = {
    "gateway": ("images/platform/gateway.Dockerfile", 8080),
    "auth": ("images/platform/auth.Dockerfile", 9000),
    "config": ("images/platform/config.Dockerfile", 8888),
    "lineage": ("images/platform/lineage.Dockerfile", 8101),
    "party-expert": ("images/verticals/party-expert.Dockerfile", 8081),
    "party-domain": ("images/verticals/party-domain.Dockerfile", 8082),
    "contract-expert": ("images/verticals/contract-expert.Dockerfile", 8085),
    "contract-domain": ("images/verticals/contract-domain.Dockerfile", 8086),
    "direct-claims-expert": ("images/verticals/direct-claims-expert.Dockerfile", 8087),
    "direct-claims-domain": ("images/verticals/direct-claims-domain.Dockerfile", 8088),
    "assumed-claims-expert": ("images/verticals/assumed-claims-expert.Dockerfile", 8089),
    "assumed-claims-domain": ("images/verticals/assumed-claims-domain.Dockerfile", 8090),
    "retrocession-expert": ("images/verticals/retrocession-expert.Dockerfile", 8093),
    "retrocession-domain": ("images/verticals/retrocession-domain.Dockerfile", 8094),
    "document-expert": ("images/verticals/document-expert.Dockerfile", 8095),
    "document-domain": ("images/verticals/document-domain.Dockerfile", 8096),
}

REPO_DOCKERFILES = {
    "policy-expert": "eia-policy-expert",
    "policy-domain": "eia-policy-domain",
    "cession-expert": "eia-cession-expert",
    "cession-domain": "eia-cession-domain",
    "notifications-expert": "eia-notifications-expert",
    "notifications-domain": "eia-notifications-domain",
    "payment-expert": "eia-payment-expert",
    "payment-domain": "eia-payment-domain",
    "shell": "eia-frontend/shell",
}


class UniqueKeyLoader(yaml.SafeLoader):
    """SafeLoader that rejects duplicate keys and resolves merge keys."""

    def construct_mapping(self, node, deep=False):
        if isinstance(node, yaml.MappingNode):
            self.flatten_mapping(node)
        mapping = {}
        for key_node, value_node in node.value:
            key = self.construct_object(key_node, deep=deep)
            if key in mapping:
                raise yaml.constructor.ConstructorError(
                    "while constructing a mapping",
                    node.start_mark,
                    f"found duplicate key {key!r}",
                    key_node.start_mark,
                )
            mapping[key] = self.construct_object(value_node, deep=deep)
        return mapping


def load_documents(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return [document for document in yaml.load_all(handle, Loader=UniqueKeyLoader) if document is not None]


def expected_images():
    images = {}
    for name, port in PLATFORM.items():
        images[f"eia-{name}"] = (f"eia/{name}:local", port)
    for vertical, tiers in VERTICALS.items():
        images[f"eia-{vertical}-expert"] = (f"eia/{vertical}-expert:local", tiers["expert"])
        images[f"eia-{vertical}-domain"] = (f"eia/{vertical}-domain:local", tiers["domain"])
    images["eia-shell"] = ("eia/shell:local", SHELL_PORT)
    images["eia-postgres"] = ("postgres:17-alpine", POSTGRES_PORT)
    return images


class Report:
    def __init__(self):
        self.failures = []
        self.checks = 0

    def ok(self, message):
        self.checks += 1
        print(f"  OK   {message}")

    def fail(self, message):
        self.checks += 1
        self.failures.append(message)
        print(f"  FAIL {message}")

    def require(self, condition, message):
        if condition:
            self.ok(message)
        else:
            self.fail(message)


def check_yaml_files(root: Path, report: Report):
    print("== YAML parse ==")
    files = []
    for pattern in ("**/*.yaml", "**/*.yml"):
        for path in root.glob(pattern):
            relative = path.relative_to(root)
            if ".git" in relative.parts or "node_modules" in relative.parts:
                continue
            if relative.parts[:3] == ("helm", "eia", "templates"):
                continue
            files.append(path)
    files = sorted(set(files))
    documents = 0
    for path in files:
        try:
            documents += len(load_documents(path))
        except yaml.YAMLError as exc:
            report.fail(f"{path.relative_to(root)}: {exc}")
    report.require(not report.failures, f"{len(files)} YAML files parsed with PyYAML {yaml.__version__}, {documents} documents")
    return files


def resolve_build(root: Path, compose_dir: Path, service: dict):
    build = service.get("build") or {}
    context = (compose_dir / build.get("context", ".")).resolve()
    dockerfile = (context / build.get("dockerfile", "Dockerfile")).resolve()
    return context, dockerfile


def check_compose(root: Path, report: Report):
    print("== Compose ==")
    compose_path = root / "compose" / "docker-compose.yml"
    documents = load_documents(compose_path)
    if len(documents) != 1:
        report.fail(f"{compose_path} must contain exactly one document")
        return
    compose = documents[0]
    services = compose.get("services", {})
    catalog = expected_images()

    report.require(set(services) == set(catalog), f"service set matches the 26-service catalog ({len(services)} found)")
    if set(services) != set(catalog):
        report.fail(f"unexpected: {sorted(set(services) - set(catalog))}; missing: {sorted(set(catalog) - set(services))}")

    ports_ok = True
    for name, (_, port) in catalog.items():
        service = services.get(name, {})
        mappings = service.get("ports", [])
        if len(mappings) != 1 or ":" not in str(mappings[0]):
            ports_ok = False
            report.fail(f"{name}: expected exactly one host:container port mapping")
            continue
        host, container = str(mappings[0]).split(":", 1)
        expected_host = SHELL_HOST_PORT if name == "eia-shell" else port
        if (host, container) != (str(expected_host), str(port)):
            ports_ok = False
            report.fail(f"{name}: port mapping {host}:{container} expected {expected_host}:{port}")
    report.require(ports_ok, "published ports match every documented service port")

    build_ok = True
    for name, service in services.items():
        if name == "eia-postgres":
            if "build" in service:
                build_ok = False
                report.fail("eia-postgres: must use the upstream image, not a local build")
            continue
        if "build" not in service:
            build_ok = False
            report.fail(f"{name}: no build section")
            continue
        context, dockerfile = resolve_build(root, compose_path.parent, service)
        if not context.is_dir():
            build_ok = False
            report.fail(f"{name}: build context {context} does not exist")
        if not dockerfile.is_file():
            build_ok = False
            report.fail(f"{name}: Dockerfile {dockerfile} does not exist")
    report.require(build_ok, "every local build context and Dockerfile resolves on disk")

    env_ok = True
    for vertical, tiers in VERTICALS.items():
        expert = services.get(f"eia-{vertical}-expert", {})
        env = expert.get("environment", {})
        if env.get("SPRING_DATASOURCE_URL") != f"jdbc:postgresql://eia-postgres:5432/{tiers['database']}":
            env_ok = False
            report.fail(f"eia-{vertical}-expert: datasource URL is wrong")
        if str(env.get("SPRING_SQL_INIT_MODE")) != "always":
            env_ok = False
            report.fail(f"eia-{vertical}-expert: SPRING_SQL_INIT_MODE is not always")
        domain = services.get(f"eia-{vertical}-domain", {})
        raw = domain.get("environment", {}).get("SPRING_APPLICATION_JSON")
        try:
            payload = json.loads(raw)
            url = payload["eia"][vertical]["expert-url"]
            if url != f"http://eia-{vertical}-expert:{tiers['expert']}":
                raise ValueError(url)
        except (TypeError, KeyError, ValueError) as exc:
            env_ok = False
            report.fail(f"eia-{vertical}-domain: SPRING_APPLICATION_JSON invalid ({exc})")
    report.require(env_ok, "domain/expert environment bindings match the service catalog")

    mounts_ok = True
    gateway = services.get("eia-gateway", {})
    if "./config/gateway/application.yml:/app/config/application.yml:ro" not in gateway.get("volumes", []):
        mounts_ok = False
        report.fail("eia-gateway: gateway config mount missing")
    shell = services.get("eia-shell", {})
    if "./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro" not in shell.get("volumes", []):
        mounts_ok = False
        report.fail("eia-shell: nginx config mount missing")
    postgres = services.get("eia-postgres", {})
    if "./initdb:/docker-entrypoint-initdb.d:ro" not in postgres.get("volumes", []):
        mounts_ok = False
        report.fail("eia-postgres: initdb mount missing")
    report.require(mounts_ok, "config, nginx and initdb bind mounts are present")

    health = postgres.get("healthcheck", {}).get("test")
    report.require(bool(health), "PostgreSQL healthcheck is defined")
    dependencies_ok = True
    for vertical in VERTICALS:
        expert = services.get(f"eia-{vertical}-expert", {})
        depends = expert.get("depends_on", {}).get("eia-postgres", {})
        if depends.get("condition") != "service_healthy":
            dependencies_ok = False
            report.fail(f"eia-{vertical}-expert: does not wait for a healthy PostgreSQL")
    report.require(dependencies_ok, "every expert waits for a healthy PostgreSQL")


def check_images(root: Path, report: Report):
    print("== Dockerfiles ==")
    repos = root.parent
    ok = True
    for name, (relative, port) in OPS_DOCKERFILES.items():
        path = root / relative
        if not path.is_file():
            ok = False
            report.fail(f"missing deployment Dockerfile {relative}")
            continue
        text = path.read_text(encoding="utf-8")
        if "build/libs/" not in text:
            ok = False
            report.fail(f"{relative}: does not copy from the Gradle build/libs output")
        if f"EXPOSE {port}" not in text:
            ok = False
            report.fail(f"{relative}: EXPOSE {port} missing")
        if 'ENTRYPOINT ["java", "-jar", "/app/app.jar"]' not in text:
            ok = False
            report.fail(f"{relative}: java entrypoint missing")
    report.require(ok, f"{len(OPS_DOCKERFILES)} deployment-owned Dockerfiles target Gradle build/libs and the correct port")

    repo_ok = True
    for name, repo in REPO_DOCKERFILES.items():
        path = repos / repo / "Dockerfile"
        if not path.is_file():
            repo_ok = False
            report.fail(f"missing repository Dockerfile for {name}: {path}")
    report.require(repo_ok, f"{len(REPO_DOCKERFILES)} owning-repository Dockerfiles exist and are used unchanged")


def check_kubernetes(root: Path, report: Report):
    print("== Kubernetes manifests ==")
    k8s = root / "k8s"
    files = sorted(k8s.rglob("*.yaml"))
    objects = []
    for path in files:
        if path.name == "kustomization.yaml":
            continue
        objects.extend(load_documents(path))
    kinds = {}
    for obj in objects:
        kinds.setdefault(obj.get("kind"), []).append(obj)

    expected = expected_images()
    deployments = {obj["metadata"]["name"]: obj for obj in kinds.get("Deployment", [])}
    services = {obj["metadata"]["name"]: obj for obj in kinds.get("Service", [])}
    report.require(set(deployments) == set(expected), f"26 Deployments present ({len(deployments)} found)")
    report.require(set(services) == set(expected), f"26 Services present ({len(services)} found)")

    namespace_ok = all(
        obj["metadata"].get("namespace") == NAMESPACE
        for obj in objects
        if obj.get("kind") != "Namespace"
    )
    report.require(namespace_ok, f"every namespaced object uses {NAMESPACE}")

    images_ok = True
    probes_ok = True
    for name, deployment in deployments.items():
        containers = deployment["spec"]["template"]["spec"]["containers"]
        container = containers[0]
        image = container["image"]
        if name == "eia-postgres":
            wanted = "postgres:17-alpine"
        else:
            wanted = f"eia/{name[4:]}:local"
        if image != wanted:
            images_ok = False
            report.fail(f"{name}: image {image} expected {wanted}")
        if name == "eia-shell":
            paths = ["/healthz"]
            need_startup = False
        elif name == "eia-postgres":
            paths = []
            need_startup = True
        else:
            paths = ["/actuator/health"]
            need_startup = True
        for probe_name in ("readinessProbe", "livenessProbe"):
            probe = container.get(probe_name)
            if not probe:
                probes_ok = False
                report.fail(f"{name}: {probe_name} missing")
                continue
            if paths:
                http_get = probe.get("httpGet", {})
                if http_get.get("path") != paths[0]:
                    probes_ok = False
                    report.fail(f"{name}: {probe_name} path {http_get.get('path')} expected {paths[0]}")
            else:
                if "exec" not in probe:
                    probes_ok = False
                    report.fail(f"{name}: {probe_name} must be an exec probe")
        if need_startup and "startupProbe" not in container:
            probes_ok = False
            report.fail(f"{name}: startupProbe missing")
    report.require(images_ok, "Deployment images match the local image catalog")
    report.require(probes_ok, "every Deployment has readiness/liveness probes; Java and PostgreSQL also have startup probes")

    services_ok = True
    for name, service in services.items():
        port = service["spec"]["ports"][0]
        wanted = expected[name][1]
        if port["port"] != wanted:
            services_ok = False
            report.fail(f"{name}: Service port {port['port']} expected {wanted}")
        selector = service["spec"].get("selector", {})
        if selector.get("app.kubernetes.io/name") != name:
            services_ok = False
            report.fail(f"{name}: Service selector does not match the Deployment")
    report.require(services_ok, "Service ports and selectors match the Deployments")

    configmaps = {obj["metadata"]["name"]: obj for obj in kinds.get("ConfigMap", [])}
    expected_configmaps = {
        "eia-gateway-config",
        "eia-config-server-config",
        "eia-shell-config",
        "eia-postgres-initdb",
    }
    report.require(set(configmaps) == expected_configmaps, "four ConfigMaps are present")
    canonical = {
        "eia-gateway-config": ("compose/config/gateway/application.yml", "application.yml"),
        "eia-config-server-config": ("compose/config/server/application.yml", "application.yml"),
        "eia-shell-config": ("compose/nginx/default.conf", "default.conf"),
        "eia-postgres-initdb": ("compose/initdb/01-create-databases.sh", "01-create-databases.sh"),
    }
    files_ok = True
    for name, (source, key) in canonical.items():
        expected_text = (root / source).read_text(encoding="utf-8").rstrip("\n")
        actual = configmaps.get(name, {}).get("data", {}).get(key)
        if actual is None or actual.rstrip("\n") != expected_text:
            files_ok = False
            report.fail(f"{name}.{key} differs from {source}")
    report.require(files_ok, "ConfigMap payloads are identical to the canonical compose files")

    secret = (kinds.get("Secret") or [{}])[0]
    secret_values = secret.get("stringData", {})
    report.require(
        secret.get("metadata", {}).get("name") == "eia-db"
        and "replace-me" in str(secret_values.get("POSTGRES_PASSWORD", "")),
        "Secret eia-db is a placeholder, not a real credential",
    )

    ingress = (kinds.get("Ingress") or [{}])[0]
    rules = ingress.get("spec", {}).get("rules", [])
    hosts = [rule.get("host") for rule in rules]
    paths = {path.get("path") for rule in rules for path in rule.get("http", {}).get("paths", [])}
    report.require(hosts == ["eia.local"] and {"/api", "/"} <= paths, "Ingress targets eia.local with /api and / paths")

    pvc = (kinds.get("PersistentVolumeClaim") or [{}])[0]
    report.require(
        pvc.get("spec", {}).get("resources", {}).get("requests", {}).get("storage") == "1Gi",
        "PostgreSQL PVC requests 1Gi",
    )

    namespace = (kinds.get("Namespace") or [{}])[0]
    report.require(
        namespace.get("metadata", {}).get("name") == NAMESPACE,
        f"Namespace {NAMESPACE} is defined",
    )

    kustomization = load_documents(k8s / "kustomization.yaml")[0]
    resources = kustomization.get("resources", [])
    missing = [item for item in resources if not (k8s / item).is_file()]
    report.require(not missing, f"kustomization lists {len(resources)} existing resources")


def check_helm(root: Path, report: Report):
    print("== Helm chart ==")
    chart_dir = root / "helm" / "eia"
    chart = load_documents(chart_dir / "Chart.yaml")[0]
    report.require(
        chart.get("apiVersion") == "v2" and chart.get("name") == "eia" and "version" in chart,
        "Chart.yaml is apiVersion v2 and names the chart",
    )
    values = load_documents(chart_dir / "values.yaml")[0]
    report.require(values.get("namespace") == NAMESPACE, f"values namespace is {NAMESPACE}")

    ports = {f"eia-{name}": service["port"] for name, service in values.get("platform", {}).items()}
    for vertical, tiers in values.get("verticals", {}).items():
        ports[f"eia-{vertical}-expert"] = tiers["expert"]["port"]
        ports[f"eia-{vertical}-domain"] = tiers["domain"]["port"]
    ports["eia-shell"] = values["shell"]["port"]
    ports["eia-postgres"] = values["postgres"]["servicePort"]
    expected_ports = {name: port for name, (_, port) in expected_images().items()}
    report.require(ports == expected_ports, "values.yaml ports match every service port")

    tags_ok = True
    for name, (_, _) in expected_images().items():
        if name == "eia-postgres":
            tag = values["postgres"]["image"]["tag"]
            repository = values["postgres"]["image"]["repository"]
            if tag != "17-alpine" or repository != "postgres":
                tags_ok = False
                report.fail("values.yaml: postgres image is not postgres:17-alpine")
            continue
        short = name[4:]
        if short == "shell":
            image = values["shell"]["image"]
        elif "-" in short and short.rsplit("-", 1)[-1] in ("expert", "domain"):
            vertical, tier = short.rsplit("-", 1)
            image = values["verticals"][vertical][tier]["image"]
        else:
            image = values["platform"][short]["image"]
        if image.get("repository") != f"eia/{short}" or image.get("tag") != "local":
            tags_ok = False
            report.fail(f"values.yaml: image tag for {name} is not eia/{short}:local")
    report.require(tags_ok, "values.yaml exposes an image repository and tag for every service")

    files_ok = True
    helm_files = {
        "gateway-application.yml": "compose/config/gateway/application.yml",
        "config-server-application.yml": "compose/config/server/application.yml",
        "shell-default.conf": "compose/nginx/default.conf",
        "postgres-initdb.sh": "compose/initdb/01-create-databases.sh",
    }
    for helm_name, source in helm_files.items():
        expected_text = (root / source).read_text(encoding="utf-8").rstrip("\n")
        actual = (chart_dir / "files" / helm_name).read_text(encoding="utf-8").rstrip("\n")
        if actual != expected_text:
            files_ok = False
            report.fail(f"helm files/{helm_name} differs from {source}")
    report.require(files_ok, "Helm file payloads are identical to the canonical compose files")

    template_ok = True
    templates = sorted(list((chart_dir / "templates").glob("*.yaml")) + list((chart_dir / "templates").glob("*.tpl")))
    for template in templates:
        text = template.read_text(encoding="utf-8")
        if "\t" in text:
            template_ok = False
            report.fail(f"{template.name}: contains a tab")
        actions = [
            line.strip()
            for line in text.splitlines()
            if line.strip().startswith("{{") and not line.strip().startswith("{{/*")
        ]
        if not all(action.endswith("}}") for action in actions):
            template_ok = False
            report.fail(f"{template.name}: a template action does not end with }}}}")
        starts = 0
        for action in actions:
            for token in ("range ", "if ", "with ", "define "):
                if token in action:
                    starts += 1
        ends = sum(1 for action in actions if "end " in action)
        if starts != ends:
            template_ok = False
            report.fail(f"{template.name}: {starts} block starts vs {ends} ends")
    report.require(template_ok, f"{len(templates)} Helm templates have balanced actions and no tabs")


def check_rendered(path: Path, label: str, report: Report, expected_objects: int):
    print(f"== {label} rendered output ==")
    try:
        objects = load_documents(path)
    except yaml.YAMLError as exc:
        report.fail(f"{path}: {exc}")
        return
    deployments = [obj for obj in objects if obj.get("kind") == "Deployment"]
    services = [obj for obj in objects if obj.get("kind") == "Service"]
    report.require(len(objects) == expected_objects, f"{expected_objects} objects rendered ({len(objects)} found)")
    report.require(len(deployments) == 26, f"26 Deployments rendered ({len(deployments)} found)")
    report.require(len(services) == 26, f"26 Services rendered ({len(services)} found)")
    probe_ok = all(
        "readinessProbe" in container and "livenessProbe" in container
        for deployment in deployments
        for container in deployment["spec"]["template"]["spec"]["containers"]
    )
    report.require(probe_ok, "every rendered Deployment has readiness and liveness probes")
    namespace_ok = all(
        obj["metadata"].get("namespace") == NAMESPACE for obj in objects if obj.get("kind") != "Namespace"
    )
    report.require(namespace_ok, f"every rendered object uses {NAMESPACE}")
    expected_ports = {name: port for name, (_, port) in expected_images().items()}
    rendered_ports = {service["metadata"]["name"]: service["spec"]["ports"][0]["port"] for service in services}
    report.require(rendered_ports == expected_ports, "rendered Service ports match the catalog")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--kubectl-rendered", type=Path)
    parser.add_argument("--helm-rendered", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()

    report = Report()
    check_yaml_files(root, report)
    check_images(root, report)
    check_compose(root, report)
    check_kubernetes(root, report)
    check_helm(root, report)
    if args.kubectl_rendered:
        check_rendered(args.kubectl_rendered, "kubectl kustomize", report, 60)
    if args.helm_rendered:
        check_rendered(args.helm_rendered, "helm template", report, 59)

    print()
    if report.failures:
        print(f"RESULT: FAIL - {len(report.failures)} of {report.checks} checks failed")
        for failure in report.failures:
            print(f"  - {failure}")
        return 1
    print(f"RESULT: PASS - {report.checks} checks, all YAML parsed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
