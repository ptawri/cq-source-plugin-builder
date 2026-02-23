# PostgreSQL destination template (placeholder / documentation only)
# The chart is destination-agnostic; copy this into your values.yaml under
# destination.spec or manage it as a separate Secret/ConfigMap.
#
# Plugin: https://hub.cloudquery.io/plugins/destination/cloudquery/postgresql

kind: destination
spec:
  name: "postgresql"
  path: "cloudquery/postgresql"
  # Pin to a specific version for reproducibility.
  # See https://hub.cloudquery.io/plugins/destination/cloudquery/postgresql/versions
  version: "v8.0.0"

  # write_mode controls how rows are written:
  #   overwrite-delete-stale  - upsert rows, delete rows not seen in this sync (default)
  #   overwrite               - upsert rows, never delete
  #   append                  - insert only, never update or delete
  write_mode: overwrite-delete-stale

  spec:
    # Use an environment variable for the connection string to avoid embedding
    # credentials in the config file. Set via Secret env vars in your pod.
    connection_string: "${POSTGRESQL_CONNECTION_STRING}"

    # Or embed directly (not recommended for production):
    # connection_string: "postgresql://user:password@host:5432/dbname?sslmode=require"

    # pgx-style pool settings (optional)
    # pgx_config:
    #   max_conns: 10

# ---------------------------------------------------------------------------
# Helm values equivalent (destination.spec in values.yaml):
# ---------------------------------------------------------------------------
# destination:
#   name: postgresql
#   path: cloudquery/postgresql
#   version: "v8.0.0"
#   spec:
#     connection_string: "${POSTGRESQL_CONNECTION_STRING}"
#
# extraEnv:
#   - name: POSTGRESQL_CONNECTION_STRING
#     valueFrom:
#       secretKeyRef:
#         name: my-pg-secret
#         key: connection_string
