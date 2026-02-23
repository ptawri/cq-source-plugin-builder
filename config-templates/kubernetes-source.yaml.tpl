# Kubernetes source configuration template
# This block configures the CloudQuery Kubernetes source plugin for in-cluster use.
# The chart renders this automatically from values; this file is provided as a
# standalone reference for users who prefer to manage configs outside Helm.
#
# Documentation: https://hub.cloudquery.io/plugins/source/cloudquery/k8s

kind: source
spec:
  name: kubernetes
  path: cloudquery/k8s
  version: "v12.0.0"

  # -----------------------------------------------------------------------
  # Tables
  # -----------------------------------------------------------------------
  # Sync all Kubernetes resource tables:
  tables:
    - "k8s_*"

  # Or list specific tables:
  # tables:
  #   - "k8s_core_pods"
  #   - "k8s_core_nodes"
  #   - "k8s_apps_deployments"
  #   - "k8s_core_services"
  #   - "k8s_core_namespaces"
  #   - "k8s_rbac_cluster_roles"
  #   - "k8s_rbac_cluster_role_bindings"

  # Skip specific tables even when using glob patterns:
  # skip_tables:
  #   - "k8s_core_secrets"    # avoid syncing secret data

  destinations:
    - "my-destination"

  # -----------------------------------------------------------------------
  # Source spec
  # -----------------------------------------------------------------------
  spec:
    # "all" - discover all API groups (recommended for full cluster inventory)
    # "core" - only core/apps/batch/networking
    discovery_filter: all

    # In-cluster auth is automatic when running inside a Kubernetes pod with
    # a mounted ServiceAccount token. No kubeconfig is needed.

    # To override and use a specific kubeconfig (e.g. for local development):
    # kubeconfig: /path/to/kubeconfig

    # To target a specific context within a kubeconfig:
    # context: my-cluster-context

    # Timeout for API calls (default: 60s)
    # timeout: 60
