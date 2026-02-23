# Snowflake destination template (placeholder / documentation only)
# The chart is destination-agnostic; copy this into your values.yaml under
# destination.spec or manage it as a separate Secret/ConfigMap.
#
# Plugin: https://hub.cloudquery.io/plugins/destination/cloudquery/snowflake

kind: destination
spec:
  name: "snowflake"
  path: "cloudquery/snowflake"
  version: "v4.0.0"

  write_mode: overwrite-delete-stale

  spec:
    # Snowflake DSN format:
    # <user>:<password>@<account>/<database>/<schema>?warehouse=<warehouse>&role=<role>
    connection_string: "${SNOWFLAKE_CONNECTION_STRING}"

    # Or break out the components:
    # connection_string: "myuser:mypassword@myaccount/mydb/public?warehouse=COMPUTE_WH&role=CLOUDQUERY_ROLE"

# ---------------------------------------------------------------------------
# Helm values equivalent (destination.spec in values.yaml):
# ---------------------------------------------------------------------------
# destination:
#   name: snowflake
#   path: cloudquery/snowflake
#   version: "v4.0.0"
#   spec:
#     connection_string: "${SNOWFLAKE_CONNECTION_STRING}"
#
# extraEnv:
#   - name: SNOWFLAKE_CONNECTION_STRING
#     valueFrom:
#       secretKeyRef:
#         name: my-snowflake-secret
#         key: connection_string
