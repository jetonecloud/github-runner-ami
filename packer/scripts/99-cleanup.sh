#!/usr/bin/env bash
# Final image hygiene: strip build-time artifacts and machine-specific state
# so every instance launched from this AMI gets a clean, unique identity and
# no leftover credentials or logs from the build.
set -euo pipefail

dnf clean all
rm -rf /var/cache/dnf /tmp/* /var/tmp/* /tmp/packer-files

# SSH is disabled (see 90-security-hardening.sh); don't ship static host
# keys either way. cloud-init would regenerate them if sshd were ever
# re-enabled, but there's no reason to carry them in the image.
rm -f /etc/ssh/ssh_host_*

# Let cloud-init treat every instance launched from this AMI as a fresh
# first boot (new instance-id, fresh user-data fetch, etc.).
cloud-init clean --logs || true
rm -rf /var/lib/cloud/instance /var/lib/cloud/instances/*

# Drop machine-specific identifiers; systemd regenerates /etc/machine-id on
# first boot when it finds it empty.
truncate -s 0 /etc/machine-id || true
rm -f /var/lib/dbus/machine-id

# Clear logs and shell history accumulated during provisioning.
find /var/log -type f -exec truncate -s 0 {} \;
rm -f /root/.bash_history /home/*/.bash_history
history -c || true

sync
