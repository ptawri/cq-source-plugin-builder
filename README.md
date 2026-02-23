# cq-source-plugin-builder

A scaffold repository for deploying [CloudQuery](https://www.cloudquery.io/) in-cluster to continuously sync Kubernetes resources (from AKS or GKE) to a configurable destination (PostgreSQL, BigQuery, Snowflake, etc.).

---

## Overview

This repository provides:

| Component | Location | Purpose |
|---|---|---|
| Helm chart | `charts/cloudquery-sync/` | Deploy CloudQuery as a CronJob or Deployment |
| Config templates | `config-templates/` | Base CloudQuery config and example destination blocks |
| Scripts | `scripts/` | Generate values files; validate the chart |
| Dockerfile | `docker/` | Pinned CloudQuery runner image for GHCR |
| CI workflows | `.github/workflows/` | Helm lint/template and Docker build |
| Example values | `examples/` | Ready-to-use values for AKS, GKE, CronJob, Deployment |

---

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Deploying to AKS](#deploying-to-aks)
- [Deploying to GKE](#deploying-to-gke)
- [CronJob vs Deployment mode](#cronjob-vs-deployment-mode)
- [Configuring Destinations](#configuring-destinations)
  - [Option A – Inline spec](#option-a--inline-spec-in-valuesyaml)
  - [Option B – Existing Secret or ConfigMap](#option-b--existing-secret-or-configmap)
  - [Option C – External Secrets Operator](#option-c--external-secrets-operator-eso)
- [RBAC and Least-Privilege Guidance](#rbac-and-least-privilege-guidance)
- [Customising Tables](#customising-tables)
- [Upgrading](#upgrading)
- [Repository Structure](#repository-structure)
- [Scripts Reference](#scripts-reference)

---

## Quick Start

```bash
# 1. Generate a platform-specific values file
./scripts/generate-config.sh --platform gke --project my-gcp-project \
  --output /tmp/values-gke.yaml

# 2. Review and edit the generated file
# 3. Deploy
helm upgrade --install cloudquery-sync charts/cloudquery-sync \
  --namespace cloudquery --create-namespace \
  -f /tmp/values-gke.yaml
```

Or use one of the included example values files directly:

```bash
helm upgrade --install cloudquery-sync charts/cloudquery-sync \
  --namespace cloudquery --create-namespace \
  -f examples/values-gke.yaml
```

---

## Deploying to AKS

### Prerequisites

1. **Azure Workload Identity** enabled on your AKS cluster.
2. An **Azure Managed Identity** (or App Registration) with permissions for your destination.
3. A **federated credential** binding the Kubernetes ServiceAccount to the Azure identity.

### Steps

```bash
# Set variables
export AZURE_CLIENT_ID="<managed-identity-client-id>"
export RELEASE_NS="cloudquery"

# Generate a values override
./scripts/generate-config.sh \
  --platform aks \
  --client-id "${AZURE_CLIENT_ID}" \
  --output /tmp/values-aks-generated.yaml

# Edit /tmp/values-aks-generated.yaml to fill in your destination config.

# Create the destination credentials Secret (if using plain Secret)
kubectl create secret generic cloudquery-pg-credentials \
  --namespace "${RELEASE_NS}" \
  --from-literal=connection_string="postgresql://user:pass@host:5432/dbname"

# Deploy
helm upgrade --install cloudquery-sync charts/cloudquery-sync \
  --namespace "${RELEASE_NS}" --create-namespace \
  -f /tmp/values-aks-generated.yaml
```

**Workload Identity annotations** are set under `serviceAccount.annotations` and `podLabels`:

```yaml
# values-aks.yaml
serviceAccount:
  annotations:
    azure.workload.identity/client-id: "<AZURE_CLIENT_ID>"

podLabels:
  azure.workload.identity/use: "true"
```

---

## Deploying to GKE

### Prerequisites

1. **Workload Identity** enabled on your GKE cluster (`--workload-pool=<PROJECT>.svc.id.goog`).
2. A **GCP Service Account** with the necessary destination permissions:
   - BigQuery: `roles/bigquery.dataEditor` + `roles/bigquery.jobUser`
   - Cloud SQL: `roles/cloudsql.client`
3. Bind the Kubernetes SA to the GCP SA:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  cq-sync@MY_PROJECT.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:MY_PROJECT.svc.id.goog[cloudquery/cloudquery-sync]"
```

### Steps

```bash
export GCP_PROJECT="my-gcp-project"
export GSA_EMAIL="cq-sync@${GCP_PROJECT}.iam.gserviceaccount.com"
export RELEASE_NS="cloudquery"

./scripts/generate-config.sh \
  --platform gke \
  --project "${GCP_PROJECT}" \
  --sa-email "${GSA_EMAIL}" \
  --output /tmp/values-gke-generated.yaml

# Edit the file to set your dataset/project and destination.

helm upgrade --install cloudquery-sync charts/cloudquery-sync \
  --namespace "${RELEASE_NS}" --create-namespace \
  -f /tmp/values-gke-generated.yaml
```

**Workload Identity annotation** is set under `serviceAccount.annotations`:

```yaml
serviceAccount:
  annotations:
    iam.gke.io/gcp-service-account: "cq-sync@my-project.iam.gserviceaccount.com"
```

---

## CronJob vs Deployment mode

Set `mode` in your values file:

| Mode | Value | Behaviour |
|---|---|---|
| CronJob | `cronjob` (default) | Runs `cloudquery sync` on a schedule; pod exits after completion |
| Deployment | `deployment` | Always-on pod; restarts after each sync (controlled by Kubernetes restart policy) |

### CronJob mode (recommended for most use cases)

```yaml
mode: cronjob

cronJob:
  schedule: "0 * * * *"        # every hour
  concurrencyPolicy: Forbid    # prevent overlapping syncs
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
```

**When to use:** When you want periodic snapshots of your cluster state. Most cost-effective option.

### Deployment mode

```yaml
mode: deployment

deployment:
  replicaCount: 1
```

**When to use:** When you want the runner to restart immediately after completing a sync (near-continuous). Be aware that without an explicit sleep, this creates a tight restart loop — consider wrapping the entrypoint or adjusting Kubernetes restart back-off settings.

---

## Configuring Destinations

The chart is **destination-agnostic**. You configure the destination via `values.yaml`. Three approaches are supported:

### Option A – Inline spec in `values.yaml`

Embed the destination spec directly. Best for simple configs or when using environment variable substitution.

```yaml
destination:
  name: postgresql
  path: cloudquery/postgresql
  version: "v8.0.0"
  spec:
    connection_string: "${POSTGRESQL_CONNECTION_STRING}"

extraEnv:
  - name: POSTGRESQL_CONNECTION_STRING
    valueFrom:
      secretKeyRef:
        name: my-pg-secret
        key: connection_string
```

See `config-templates/destinations/` for ready-to-copy examples for PostgreSQL, BigQuery, and Snowflake.

### Option B – Existing Secret or ConfigMap

Mount the full CloudQuery destination config block from a pre-existing Secret or ConfigMap. The chart passes both the source and destination files to `cloudquery sync`.

```yaml
destination:
  name: postgresql
  existingSecret:
    name: my-cloudquery-destination-config
    key: destination.yaml     # must be a valid CloudQuery destination block
```

The Secret must contain a full CloudQuery destination config block under the specified key:

```yaml
# Secret data (value of key "destination.yaml"):
kind: destination
spec:
  name: postgresql
  path: cloudquery/postgresql
  version: "v8.0.0"
  spec:
    connection_string: "postgresql://user:pass@host:5432/db"
```

Similarly for ConfigMap:

```yaml
destination:
  name: postgresql
  existingConfigMap:
    name: my-cloudquery-destination-config
    key: destination.yaml
```

### Option C – External Secrets Operator (ESO)

When ESO is installed in your cluster, the chart can render an `ExternalSecret` resource that automatically pulls credentials from your secrets store (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager, HashiCorp Vault, etc.).

```yaml
externalSecret:
  enabled: true
  refreshInterval: "1h"
  secretStoreRef:
    name: my-vault-store        # name of your ESO SecretStore/ClusterSecretStore
    kind: ClusterSecretStore
  data:
    - secretKey: connection_string
      remoteRef:
        key: cloudquery/pg-connection-string   # path in your secrets store
```

The ESO-managed Secret is then referenced as an environment variable:

```yaml
destination:
  name: postgresql
  path: cloudquery/postgresql
  version: "v8.0.0"
  spec:
    connection_string: "${POSTGRESQL_CONNECTION_STRING}"

extraEnv:
  - name: POSTGRESQL_CONNECTION_STRING
    valueFrom:
      secretKeyRef:
        name: cloudquery-sync-destination-credentials   # ESO-managed Secret name
        key: connection_string
```

---

## RBAC and Least-Privilege Guidance

By default the chart creates a `ClusterRole` that grants `get/list/watch` on most standard Kubernetes API groups. This is read-only and covers the resources that the CloudQuery Kubernetes source plugin syncs.

### Cluster-wide vs namespaced

```yaml
rbac:
  create: true
  clusterWide: true    # ClusterRole + ClusterRoleBinding (default)
```

For a namespaced setup (only sync a specific namespace):

1. Set `rbac.clusterWide: false` — the chart will **not** create cluster-scoped resources.
2. Manually create a `Role` and `RoleBinding` in each target namespace.

### Adding extra permissions

Use `rbac.extraRules` to append additional rules without forking the chart:

```yaml
rbac:
  extraRules:
    - apiGroups: ["custom.io"]
      resources: ["myresources"]
      verbs: ["get", "list", "watch"]
```

### Restricting Secrets access

The default ClusterRole includes `secrets` in the core API group. If you do not need to sync Secret resources, disable chart-managed RBAC and provide your own minimal ClusterRole:

```yaml
rbac:
  create: false
serviceAccount:
  create: true
  name: cloudquery-sync
```

### Workload Identity (AKS / GKE)

- **GKE**: annotate the `serviceAccount` with `iam.gke.io/gcp-service-account`.
- **AKS**: annotate with `azure.workload.identity/client-id` and add the `azure.workload.identity/use: "true"` pod label.

These annotations are surfaced as first-class values — see `examples/values-gke.yaml` and `examples/values-aks.yaml`.

---

## Customising Tables

By default all `k8s_*` tables are synced. To limit scope:

```yaml
source:
  tables:
    - "k8s_core_pods"
    - "k8s_core_nodes"
    - "k8s_apps_deployments"
    - "k8s_core_services"
    - "k8s_core_namespaces"
```

To exclude sensitive tables:

```yaml
source:
  tables:
    - "k8s_*"
  skipTables:
    - "k8s_core_secrets"
```

See the [CloudQuery Kubernetes plugin docs](https://hub.cloudquery.io/plugins/source/cloudquery/k8s) for the full table list.

---

## Upgrading

```bash
# Pull latest chart changes, then:
helm upgrade cloudquery-sync charts/cloudquery-sync \
  --namespace cloudquery \
  -f your-values.yaml
```

---

## Repository Structure

```
.
├── charts/
│   └── cloudquery-sync/          # Helm chart
│       ├── Chart.yaml
│       ├── values.yaml           # Default values (annotated)
│       └── templates/
│           ├── _helpers.tpl
│           ├── serviceaccount.yaml
│           ├── clusterrole.yaml
│           ├── clusterrolebinding.yaml
│           ├── configmap.yaml    # Rendered CloudQuery config
│           ├── secret.yaml       # Plain K8s Secret (optional)
│           ├── externalsecret.yaml  # ESO ExternalSecret (optional)
│           ├── cronjob.yaml      # mode=cronjob
│           └── deployment.yaml   # mode=deployment
├── config-templates/
│   ├── cloudquery-config.yaml.tpl      # Base config template
│   ├── kubernetes-source.yaml.tpl      # Kubernetes source block
│   └── destinations/
│       ├── postgres.yaml.tpl           # PostgreSQL example
│       ├── bigquery.yaml.tpl           # BigQuery example (GKE)
│       └── snowflake.yaml.tpl          # Snowflake example
├── docker/
│   └── Dockerfile                # Pinned CloudQuery runner image
├── examples/
│   ├── values-aks.yaml           # AKS-specific values
│   ├── values-gke.yaml           # GKE-specific values
│   ├── values-cronjob.yaml       # CronJob mode example
│   └── values-deployment.yaml    # Deployment mode example
├── scripts/
│   ├── generate-config.sh        # Generates platform-specific values
│   └── validate.sh               # Validates the Helm chart
└── .github/
    └── workflows/
        ├── helm-lint.yaml        # Helm lint + template CI
        └── docker-build.yaml     # Docker build + GHCR publish CI
```

---

## Scripts Reference

### `scripts/generate-config.sh`

Generates a Helm values override file for a specific platform.

```bash
./scripts/generate-config.sh \
  --platform gke \
  --project my-gcp-project \
  --sa-email cq-sync@my-project.iam.gserviceaccount.com \
  --mode cronjob \
  --schedule "0 * * * *" \
  --output values-generated.yaml
```

### `scripts/validate.sh`

Runs `helm lint` and a suite of `helm template` checks to verify the chart renders correctly in all modes.

```bash
./scripts/validate.sh
./scripts/validate.sh --values examples/values-aks.yaml
./scripts/validate.sh --values examples/values-gke.yaml
```
