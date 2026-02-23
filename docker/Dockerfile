# CloudQuery runner image
# Extends the official CloudQuery image with optional additional tooling.
# By default this simply re-tags the upstream image for pinning / GHCR mirroring.
#
# Build:
#   docker build -t ghcr.io/<your-org>/cloudquery-runner:latest docker/
#
# Run locally (requires a valid config):
#   docker run --rm \
#     -v $(pwd)/config-templates/cloudquery-config.yaml.tpl:/etc/cloudquery/config.yaml:ro \
#     ghcr.io/<your-org>/cloudquery-runner:latest \
#     cloudquery sync /etc/cloudquery/config.yaml

ARG CLOUDQUERY_VERSION=6.5.0
FROM ghcr.io/cloudquery/cloudquery:${CLOUDQUERY_VERSION}

# Add any extra tooling here (e.g. cloud CLIs for credential helpers).
# Keep the image minimal to reduce attack surface.

# Switch to a non-root user (the base image already runs as non-root).
# Uncomment if you need to install packages:
# USER root
# RUN apk add --no-cache curl
# USER nonroot

LABEL org.opencontainers.image.source="https://github.com/ptawri/cq-source-plugin-builder"
LABEL org.opencontainers.image.description="CloudQuery in-cluster Kubernetes sync runner"
LABEL org.opencontainers.image.licenses="Apache-2.0"
