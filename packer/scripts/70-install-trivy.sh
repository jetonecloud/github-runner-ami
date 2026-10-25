#!/usr/bin/env bash
# Trivy, installed from the official release tarball and verified against
# the upstream checksums.txt. Installed early so 95-trivy-scan.sh can scan
# the finished filesystem before the AMI is sealed.
set -euo pipefail

: "${TRIVY_VERSION:?missing}" "${TRIVY_ARCH:?missing}" "${TRIVY_CHECKSUM:?missing}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

tarball="trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz"
curl -fsSL -o "${workdir}/${tarball}" \
  "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${tarball}"

echo "${TRIVY_CHECKSUM}  ${workdir}/${tarball}" | sha256sum -c -

tar -xzf "${workdir}/${tarball}" -C "${workdir}"
install -m 0755 "${workdir}/trivy" /usr/local/bin/trivy

trivy --version
