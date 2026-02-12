#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

IMAGE_NAME="${IMAGE_NAME:-mt-base-image}"
PERL_VERSIONS=("5.16" "5.32")
HEALTHCHECK_TIMEOUT=60
FAILURES=0

# shellcheck disable=SC2329
cleanup() {
    echo "=== Cleaning up ==="
    docker compose -f "${PROJECT_ROOT}/compose.yml" down --timeout 10 2>/dev/null || true
}
trap cleanup EXIT

fail() {
    echo "FAIL: $1" >&2
    FAILURES=$((FAILURES + 1))
}

# --------------------------------------------------
# 1. Static analysis (optional — skip if tools missing)
# --------------------------------------------------
echo "=== Step 1: Static analysis ==="

if command -v hadolint &>/dev/null; then
    echo "Running hadolint..."
    for version in "${PERL_VERSIONS[@]}"; do
        if hadolint "${PROJECT_ROOT}/perl-${version}/Dockerfile"; then
            echo "  hadolint perl-${version}/Dockerfile ... OK"
        else
            fail "hadolint perl-${version}/Dockerfile"
        fi
    done
else
    echo "WARNING: hadolint not found, skipping Dockerfile lint"
fi

if command -v shellcheck &>/dev/null; then
    echo "Running shellcheck..."
    shellcheck_targets=("${SCRIPT_DIR}"/*.sh "${PROJECT_ROOT}/common/entrypoint.sh")
    for target in "${shellcheck_targets[@]}"; do
        name="${target#"${PROJECT_ROOT}/"}"
        if shellcheck "${target}"; then
            echo "  shellcheck ${name} ... OK"
        else
            fail "shellcheck ${name}"
        fi
    done
else
    echo "WARNING: shellcheck not found, skipping shell script lint"
fi

# --------------------------------------------------
# 2. Image build
# --------------------------------------------------
echo "=== Step 2: Building images ==="
"${SCRIPT_DIR}/build-all.sh"

# --------------------------------------------------
# 3. Start containers
# --------------------------------------------------
echo "=== Step 3: Starting containers ==="
docker compose -f "${PROJECT_ROOT}/compose.yml" up -d

wait_for_port() {
    local port=$1
    local elapsed=0
    printf "  localhost:%s ..." "${port}"
    while [ "${elapsed}" -lt "${HEALTHCHECK_TIMEOUT}" ]; do
        if curl --silent --max-time 2 -o /dev/null "http://localhost:${port}/"; then
            echo " reachable (${elapsed}s)"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        printf "."
    done
    echo " TIMEOUT"
    return 1
}

echo "Waiting for containers to become healthy (max ${HEALTHCHECK_TIMEOUT}s)..."
for port in 5016 5032; do
    if ! wait_for_port "${port}"; then
        docker compose -f "${PROJECT_ROOT}/compose.yml" logs 2>&1 | tail -20
        fail "localhost:${port} did not become reachable within ${HEALTHCHECK_TIMEOUT}s"
    fi
done

# --------------------------------------------------
# 4. HTTP response verification
# --------------------------------------------------
echo "=== Step 4: HTTP response verification ==="

verify_response() {
    local port=$1
    local expected=$2
    local body
    body="$(curl --silent --max-time 5 "http://localhost:${port}/")"
    if echo "${body}" | grep -q "${expected}"; then
        echo "  localhost:${port} contains '${expected}' ... OK"
    else
        fail "localhost:${port} expected '${expected}', got: ${body}"
    fi
}

verify_response 5016 "Perl 5.016"
verify_response 5032 "Perl 5.032"

# --------------------------------------------------
# 5. Module loading verification
# --------------------------------------------------
echo "=== Step 5: Module loading verification ==="

for version in "${PERL_VERSIONS[@]}"; do
    image="${IMAGE_NAME}:perl-${version}"
    if docker run --rm --entrypoint perl "${image}" -e 'use DBI; use Plack; use Starman; print "OK\n"' | grep -q "OK"; then
        echo "  ${image} module load ... OK"
    else
        fail "${image} module loading failed"
    fi
done

# --------------------------------------------------
# 6. Proclet process verification
# --------------------------------------------------
echo "=== Step 6: Proclet process verification ==="

verify_workers() {
    local service=$1
    local expected_count=6  # 1 master + 5 workers
    local count
    count="$(docker compose -f "${PROJECT_ROOT}/compose.yml" exec -T "${service}" pgrep -c starman 2>/dev/null || echo 0)"
    # Trim whitespace
    count="$(echo "${count}" | tr -d '[:space:]')"
    if [ "${count}" -ge "${expected_count}" ]; then
        echo "  ${service}: ${count} starman processes (expected >= ${expected_count}) ... OK"
    else
        fail "${service}: ${count} starman processes (expected >= ${expected_count})"
    fi
}

verify_workers perl-516
verify_workers perl-532

# --------------------------------------------------
# 7. Cleanup is handled by the EXIT trap
# --------------------------------------------------

# --------------------------------------------------
# Summary
# --------------------------------------------------
echo ""
if [ "${FAILURES}" -eq 0 ]; then
    echo "=== All verification steps PASSED ==="
    exit 0
else
    echo "=== ${FAILURES} verification step(s) FAILED ===" >&2
    exit 1
fi
