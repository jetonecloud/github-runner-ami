#!/usr/bin/env bash
# Scan the fully-provisioned root filesystem with Trivy before the AMI is
# sealed. Fails the build if TRIVY_FAIL_SEVERITY findings are present, so
# vulnerable images never get published.
set -euo pipefail

: "${TRIVY_FAIL_SEVERITY:?missing}"

report=/tmp/trivy-fs-report.json

args=(fs / --skip-dirs /proc --skip-dirs /sys --format json --output "${report}")
if [ -n "${TRIVY_FAIL_SEVERITY}" ]; then
  args+=(--severity "${TRIVY_FAIL_SEVERITY}" --exit-code 1)
fi

set +e
trivy "${args[@]}"
status=$?
set -e

# Always print a human-readable table to the build log, regardless of gate
# outcome, so failures are visible without pulling the JSON report.
trivy fs / --skip-dirs /proc --skip-dirs /sys --format table || true

if [ "${status}" -ne 0 ]; then
  echo "Trivy found ${TRIVY_FAIL_SEVERITY} findings - failing the build. See ${report}." >&2
  exit "${status}"
fi
