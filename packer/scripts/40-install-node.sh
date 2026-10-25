#!/usr/bin/env bash
# Node.js LTS, installed from the official pre-built tarball and verified
# against the upstream SHASUMS256.txt checksum.
set -euo pipefail

: "${NODE_VERSION:?missing}" "${NODE_ARCH:?missing}" "${NODE_CHECKSUM:?missing}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

tarball="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
curl -fsSL -o "${workdir}/${tarball}" \
  "https://nodejs.org/dist/v${NODE_VERSION}/${tarball}"

echo "${NODE_CHECKSUM}  ${workdir}/${tarball}" | sha256sum -c -

tar -xJf "${workdir}/${tarball}" -C /usr/local --strip-components=1

node --version
npm --version
