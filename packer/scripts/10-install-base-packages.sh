#!/usr/bin/env bash
# Base tooling the runner and provisioning scripts depend on, plus the
# unprivileged system user that will own and run the GitHub Actions runner.
set -euo pipefail

dnf -y install \
  git \
  jq \
  unzip \
  tar \
  gzip \
  which \
  shadow-utils \
  util-linux \
  chrony \
  amazon-ssm-agent \
  findutils \
  procps-ng

systemctl enable chronyd
systemctl enable amazon-ssm-agent

# Dedicated, non-login, non-root user that owns /opt/actions-runner and runs
# the runner process + jobs. Added to the docker group in 20-install-docker.sh.
if ! id -u runner >/dev/null 2>&1; then
  useradd --system --create-home --home-dir /home/runner --shell /sbin/nologin runner
fi

dnf clean all
