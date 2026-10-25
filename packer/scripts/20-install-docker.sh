#!/usr/bin/env bash
# Docker Engine (from the AL2023 repos) plus the buildx CLI plugin
# (downloaded directly from GitHub, pinned by version + SHA-256).
set -euo pipefail

: "${BUILDX_VERSION:?missing}" "${BUILDX_CHECKSUM:?missing}" "${GO_ARCH:?missing}"

dnf -y install docker
systemctl enable docker

install -d -m 0755 /usr/libexec/docker/cli-plugins

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

buildx_bin="${workdir}/docker-buildx"
curl -fsSL -o "${buildx_bin}" \
  "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-${GO_ARCH}"

echo "${BUILDX_CHECKSUM}  ${buildx_bin}" | sha256sum -c -

install -m 0755 "${buildx_bin}" /usr/libexec/docker/cli-plugins/docker-buildx

# docker group membership for the runner user and the default ec2-user
# (useful for interactive debugging over SSM Session Manager).
groupadd -f docker
usermod -aG docker runner
usermod -aG docker ec2-user || true

docker --version
docker buildx version
