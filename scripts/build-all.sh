#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=config.sh disable=SC1091
source "${SCRIPT_DIR}/config.sh"

for version in "${PERL_VERSIONS[@]}"; do
    full_image="${IMAGE_NAME}:perl-${version}"

    echo "=== Building ${full_image} ==="
    docker build \
        -f "${PROJECT_ROOT}/perl-${version}/Dockerfile" \
        -t "${full_image}" \
        "${PROJECT_ROOT}"
    echo "=== Successfully built ${full_image} ==="
done

echo "=== All images built successfully ==="
