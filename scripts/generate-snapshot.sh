#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PERL_VERSION="${1:-5.32}"

echo "=== Building builder stage for perl-${PERL_VERSION} ==="
docker build \
    -f "${PROJECT_ROOT}/perl-${PERL_VERSION}/Dockerfile" \
    --target builder \
    -t "mt-builder:perl-${PERL_VERSION}" \
    "${PROJECT_ROOT}"

echo "=== Generating cpanfile.snapshot using mt-builder:perl-${PERL_VERSION} ==="
docker run --rm \
    -v "${PROJECT_ROOT}/common:/work" \
    -w /work \
    "mt-builder:perl-${PERL_VERSION}" \
    bash -c "
        cpanm Carton --notest 2>&1 && \
        carton install 2>&1 && \
        echo '=== Snapshot generated ==='
    "

if [ ! -f "${PROJECT_ROOT}/common/cpanfile.snapshot" ]; then
    echo "ERROR: cpanfile.snapshot was not created. Check the carton install output above." >&2
    exit 1
fi

echo "=== cpanfile.snapshot written to common/cpanfile.snapshot ==="
