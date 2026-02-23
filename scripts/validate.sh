#!/usr/bin/env bash
# validate.sh
# Validates the Helm chart and optionally tests templating with example values.
#
# Usage:
#   ./scripts/validate.sh
#   ./scripts/validate.sh --values examples/values-aks.yaml
#   ./scripts/validate.sh --values examples/values-gke.yaml
#   ./scripts/validate.sh --values examples/values-deployment.yaml
#
# Requirements: bash >= 4, helm >= 3

set -euo pipefail
IFS=$'\n\t'

CHART_DIR="${CHART_DIR:-charts/cloudquery-sync}"
VALUES_FILES=()
STRICT=false

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --chart     Path to the Helm chart directory  (default: charts/cloudquery-sync)
  --values    Additional values file(s) to use with helm template
  --strict    Exit non-zero on any warning
  -h, --help  Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chart)   CHART_DIR="$2";      shift 2 ;;
    --values)  VALUES_FILES+=("$2"); shift 2 ;;
    --strict)  STRICT=true;          shift ;;
    -h|--help) usage; exit 0 ;;
    *)         echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; exit 1; }
info() { echo "→ $1"; }

# ---------------------------------------------------------------------------
# Check prerequisites
# ---------------------------------------------------------------------------
info "Checking prerequisites..."
if ! command -v helm &>/dev/null; then
  fail "helm not found. Install from https://helm.sh/docs/intro/install/"
fi
helm version --short
pass "helm found"

# ---------------------------------------------------------------------------
# helm lint
# ---------------------------------------------------------------------------
info "Running helm lint..."

LINT_CMD=(helm lint "${CHART_DIR}")
for vf in "${VALUES_FILES[@]+"${VALUES_FILES[@]}"}"; do
  LINT_CMD+=(-f "$vf")
done

if "${LINT_CMD[@]}"; then
  pass "helm lint passed"
else
  fail "helm lint failed"
fi

# ---------------------------------------------------------------------------
# helm template - default values (CronJob mode)
# ---------------------------------------------------------------------------
info "Templating chart with default values (CronJob mode)..."
TEMPLATE_OUT=$(helm template validate-test "${CHART_DIR}")

echo "$TEMPLATE_OUT" | grep -q "kind: CronJob"    && pass "CronJob rendered" || fail "CronJob not found in output"
echo "$TEMPLATE_OUT" | grep -q "kind: ServiceAccount" && pass "ServiceAccount rendered" || fail "ServiceAccount not found"
echo "$TEMPLATE_OUT" | grep -q "kind: ClusterRole"    && pass "ClusterRole rendered"    || fail "ClusterRole not found"
echo "$TEMPLATE_OUT" | grep -q "kind: ClusterRoleBinding" && pass "ClusterRoleBinding rendered" || fail "ClusterRoleBinding not found"
echo "$TEMPLATE_OUT" | grep -q "kind: ConfigMap"  && pass "ConfigMap rendered"  || fail "ConfigMap not found"
echo "$TEMPLATE_OUT" | grep -vq "kind: Deployment" && pass "Deployment NOT rendered (CronJob mode)" || fail "Deployment should not be rendered in CronJob mode"
echo "$TEMPLATE_OUT" | grep -vq "kind: ExternalSecret" && pass "ExternalSecret NOT rendered (disabled by default)" || fail "ExternalSecret should not be rendered by default"

# ---------------------------------------------------------------------------
# helm template - Deployment mode
# ---------------------------------------------------------------------------
info "Templating chart with Deployment mode..."
DEPLOY_OUT=$(helm template validate-test "${CHART_DIR}" --set mode=deployment)

echo "$DEPLOY_OUT" | grep -q "kind: Deployment"  && pass "Deployment rendered" || fail "Deployment not found in deployment mode"
echo "$DEPLOY_OUT" | grep -vq "kind: CronJob"    && pass "CronJob NOT rendered (deployment mode)" || fail "CronJob should not be rendered in deployment mode"

# ---------------------------------------------------------------------------
# helm template - ExternalSecret enabled
# ---------------------------------------------------------------------------
info "Templating chart with ExternalSecret enabled..."
ESO_OUT=$(helm template validate-test "${CHART_DIR}" \
  --set externalSecret.enabled=true \
  --set externalSecret.secretStoreRef.name=my-store)

echo "$ESO_OUT" | grep -q "kind: ExternalSecret" && pass "ExternalSecret rendered when enabled" || fail "ExternalSecret not found when enabled"

# ---------------------------------------------------------------------------
# helm template - inline destination spec
# ---------------------------------------------------------------------------
info "Templating chart with inline destination.spec..."
INLINE_OUT=$(helm template validate-test "${CHART_DIR}" \
  --set destination.path=cloudquery/postgresql \
  --set destination.version=v8.0.0 \
  --set "destination.spec.connection_string=postgresql://localhost/test")

echo "$INLINE_OUT" | grep -q "connection_string" && pass "Inline destination spec rendered" || fail "Inline destination spec not found"

# ---------------------------------------------------------------------------
# helm template - existingSecret destination
# ---------------------------------------------------------------------------
info "Templating chart with destination.existingSecret..."
SECRET_OUT=$(helm template validate-test "${CHART_DIR}" \
  --set destination.existingSecret.name=my-dest-secret)

echo "$SECRET_OUT" | grep -q "my-dest-secret" && pass "ExistingSecret volume reference rendered" || fail "ExistingSecret reference not found"
echo "$SECRET_OUT" | grep -q "destination.yaml" && pass "destination.yaml mount path present" || fail "destination.yaml mount not found"

# ---------------------------------------------------------------------------
# User-supplied values files
# ---------------------------------------------------------------------------
if [[ ${#VALUES_FILES[@]} -gt 0 ]]; then
  info "Templating with user-supplied values files..."
  EXTRA_CMD=(helm template validate-test "${CHART_DIR}")
  for vf in "${VALUES_FILES[@]}"; do
    EXTRA_CMD+=(-f "$vf")
    echo "  Using: $vf"
  done
  if "${EXTRA_CMD[@]}" > /dev/null; then
    pass "Template with user values succeeded"
  else
    fail "Template with user values failed"
  fi
fi

echo ""
echo "All validations passed."
