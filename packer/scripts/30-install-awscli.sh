#!/usr/bin/env bash
# AWS CLI v2, installed from the official versioned zip and verified against
# the AWS CLI Team's published GPG signature (AWS doesn't publish a static
# sha256 for this artifact, so signature verification is the correct check).
# See: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-gpg-verify.html
set -euo pipefail

: "${AWSCLI_VERSION:?missing}" "${AWSCLI_ARCH:?missing}" "${AWSCLI_GPG_FINGERPRINT:?missing}"

dnf -y install gnupg2

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT
cd "${workdir}"

zip_name="awscli-exe-linux-${AWSCLI_ARCH}-${AWSCLI_VERSION}.zip"
curl -fsSL -o "${zip_name}" "https://awscli.amazonaws.com/${zip_name}"
curl -fsSL -o "${zip_name}.sig" "https://awscli.amazonaws.com/${zip_name}.sig"

export GNUPGHOME="${workdir}/gnupg"
mkdir -p "${GNUPGHOME}"
chmod 0700 "${GNUPGHOME}"

key_imported=0
for keyserver in hkps://keys.openpgp.org hkps://keyserver.ubuntu.com; do
  if gpg --batch --keyserver "${keyserver}" --recv-keys "${AWSCLI_GPG_FINGERPRINT}"; then
    key_imported=1
    break
  fi
done
[ "${key_imported}" -eq 1 ] || { echo "Failed to fetch AWS CLI signing key" >&2; exit 1; }

fetched_fingerprint="$(gpg --batch --with-colons --fingerprint "${AWSCLI_GPG_FINGERPRINT}" | awk -F: '/^fpr:/ {print $10; exit}')"
if [ "${fetched_fingerprint}" != "${AWSCLI_GPG_FINGERPRINT}" ]; then
  echo "AWS CLI GPG key fingerprint mismatch: got ${fetched_fingerprint}, expected ${AWSCLI_GPG_FINGERPRINT}" >&2
  exit 1
fi

gpg --batch --verify "${zip_name}.sig" "${zip_name}"

unzip -q "${zip_name}"
./aws/install --update

aws --version
