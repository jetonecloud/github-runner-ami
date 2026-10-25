#!/usr/bin/env bash
# GitHub Actions runner binary, installed from the official release tarball
# and verified against the SHA-256 published in the GitHub release notes.
# NOT configured/registered here - that happens at instance boot (see
# packer/files/scripts/runner-register.sh) so no token ever lives in the AMI.
set -euo pipefail

: "${RUNNER_VERSION:?missing}" "${RUNNER_ARCH:?missing}" "${RUNNER_CHECKSUM:?missing}"

install_dir=/opt/actions-runner
install -d -m 0755 -o runner -g runner "${install_dir}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

tarball="actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
curl -fsSL -o "${workdir}/${tarball}" \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${tarball}"

echo "${RUNNER_CHECKSUM}  ${workdir}/${tarball}" | sha256sum -c -

tar -xzf "${workdir}/${tarball}" -C "${install_dir}"
chown -R runner:runner "${install_dir}"

# Installs the runner's native (libicu, etc.) OS dependencies.
"${install_dir}/bin/installdependencies.sh"

# Working directory for job checkouts; wiped between jobs by runner-cleanup.sh.
install -d -m 0755 -o runner -g runner "${install_dir}/_work"

sudo -u runner "${install_dir}/run.sh" --version || true
