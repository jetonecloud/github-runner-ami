#!/usr/bin/env bash
# Go toolchain, installed from the official tarball and verified against the
# checksum published at https://go.dev/dl/?mode=json.
set -euo pipefail

: "${GO_VERSION:?missing}" "${GO_ARCH:?missing}" "${GO_CHECKSUM:?missing}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

tarball="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
curl -fsSL -o "${workdir}/${tarball}" "https://go.dev/dl/${tarball}"

echo "${GO_CHECKSUM}  ${workdir}/${tarball}" | sha256sum -c -

rm -rf /usr/local/go
tar -xzf "${workdir}/${tarball}" -C /usr/local

cat >/etc/profile.d/golang.sh <<'EOF'
export PATH="$PATH:/usr/local/go/bin"
EOF
chmod 0644 /etc/profile.d/golang.sh

/usr/local/go/bin/go version
