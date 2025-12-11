#!/usr/bin/env bash
#
# podman-build.sh - Linux/macOS Podman Build Script
#
# This script automates the process of building and running the Podman container
# with version information dynamically injected at build time.

set -euo pipefail

# Ensure Podman and a Compose implementation are available.
if ! command -v podman >/dev/null 2>&1; then
  echo "Error: Podman is required but not installed or not on PATH."
  exit 1
fi

if podman compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(podman compose)
elif command -v podman-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(podman-compose)
else
  echo "Error: neither 'podman compose' nor 'podman-compose' is available."
  exit 1
fi

COMPOSE_CMD_PRETTY="${COMPOSE_CMD[*]}"
CLI_PROXY_IMAGE_DEFAULT="${CLI_PROXY_IMAGE:-localhost/cli-proxy-api:local}"
export CLI_PROXY_IMAGE="${CLI_PROXY_IMAGE_DEFAULT}"

echo "Please select an option:"
echo "1) Run using existing local image (no pull/build)"
echo "2) Build from Source and Run (For Developers)"
read -r -p "Enter choice [1-2]: " choice

case "$choice" in
  1)
    echo "--- Running with existing local image (Podman) ---"
    echo "Using image: ${CLI_PROXY_IMAGE}"
    "${COMPOSE_CMD[@]}" -f podman-compose.yml up -d --remove-orphans --no-build --pull never
    echo "Services are starting from local image."
    echo "Run '${COMPOSE_CMD_PRETTY} -f podman-compose.yml logs -f' to see the logs."
    ;;
  2)
    echo "--- Building from Source and Running (Podman) ---"

    VERSION="$(git describe --tags --always --dirty)"
    COMMIT="$(git rev-parse --short HEAD)"
    BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    echo "Building with the following info:"
    echo "  Version: ${VERSION}"
    echo "  Commit: ${COMMIT}"
    echo "  Build Date: ${BUILD_DATE}"
    echo "----------------------------------------"

    export CLI_PROXY_IMAGE="${CLI_PROXY_IMAGE_DEFAULT}"
    echo "Using image: ${CLI_PROXY_IMAGE}"

    echo "Building the Podman image..."
    "${COMPOSE_CMD[@]}" -f podman-compose.yml build \
      --build-arg VERSION="${VERSION}" \
      --build-arg COMMIT="${COMMIT}" \
      --build-arg BUILD_DATE="${BUILD_DATE}"

    echo "Starting the services..."
    "${COMPOSE_CMD[@]}" -f podman-compose.yml up -d --remove-orphans --pull never

    echo "Build complete. Services are starting."
    echo "Run '${COMPOSE_CMD_PRETTY} -f podman-compose.yml logs -f' to see the logs."
    ;;
  *)
    echo "Invalid choice. Please enter 1 or 2."
    exit 1
    ;;
esac
