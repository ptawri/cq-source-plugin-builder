# BigQuery destination template (placeholder / documentation only)
# The chart is destination-agnostic; copy this into your values.yaml under
# destination.spec or manage it as a separate Secret/ConfigMap.
#
# Plugin: https://hub.cloudquery.io/plugins/destination/cloudquery/bigquery
#
# GKE Workload Identity note:
#   When running on GKE with Workload Identity, annotate the ServiceAccount:
#     serviceAccount:
#       annotations:
#         iam.gke.io/gcp-service-account: my-sa@my-project.iam.gserviceaccount.com
#   Grant the GCP SA BigQuery Data Editor + Job User roles on the dataset/project.

kind: destination
spec:
  name: "bigquery"
  path: "cloudquery/bigquery"
  version: "v4.0.0"

  write_mode: overwrite-delete-stale

  spec:
    # GCP project that hosts the BigQuery dataset.
    project_id: "${GCP_PROJECT_ID}"

    # BigQuery dataset to write tables into.
    dataset_id: "cloudquery_k8s"

    # Optional: geographic location for the dataset (default: US)
    # dataset_location: "EU"

    # Optional: time partitioning type (DAY, HOUR, MONTH, YEAR)
    # time_partitioning: DAY

# ---------------------------------------------------------------------------
# Helm values equivalent (destination.spec in values.yaml):
# ---------------------------------------------------------------------------
# destination:
#   name: bigquery
#   path: cloudquery/bigquery
#   version: "v4.0.0"
#   spec:
#     project_id: "my-gcp-project"
#     dataset_id: "cloudquery_k8s"
#
# serviceAccount:
#   annotations:
#     iam.gke.io/gcp-service-account: cq-sync@my-gcp-project.iam.gserviceaccount.com
