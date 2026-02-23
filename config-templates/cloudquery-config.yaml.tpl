# CloudQuery base configuration template
# Copy this file and fill in the destination block appropriate for your environment.
# See config-templates/destinations/ for destination-specific examples.
#
# Usage:
#   cloudquery sync config.yaml
#   cloudquery sync source-config.yaml destination-config.yaml

---
# ---------------------------------------------------------------------------
# Kubernetes source (in-cluster auth via ServiceAccount token)
# ---------------------------------------------------------------------------
kind: source
spec:
  name: kubernetes
  path: cloudquery/k8s
  # Pin to a specific version for reproducibility.
  # See https://hub.cloudquery.io/plugins/source/cloudquery/k8s/versions
  version: "v12.0.0"

  # Tables to sync. Supports glob patterns.
  # Use "k8s_*" for all tables, or list specific ones.
  tables:
    - "k8s_*"

  # Tables to explicitly exclude.
  # skip_tables:
  #   - "k8s_core_secrets"

  # One or more destination names (must match a destination block name below).
  destinations:
    - "my-destination"

  spec:
    # "all" discovers tables from all API groups.
    # Use "core" to limit to core/apps/batch/networking.
    discovery_filter: all

    # Uncomment to use an explicit kubeconfig instead of in-cluster auth.
    # kubeconfig: /path/to/kubeconfig

---
# ---------------------------------------------------------------------------
# Destination block
# Replace with your actual destination. See destinations/ for examples.
# ---------------------------------------------------------------------------
kind: destination
spec:
  name: "my-destination"
  path: "cloudquery/postgresql"
  version: "v8.0.0"
  spec:
    connection_string: "${DESTINATION_CONNECTION_STRING}"
