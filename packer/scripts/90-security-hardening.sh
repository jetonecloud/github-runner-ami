#!/usr/bin/env bash
# Hardening for the image that will run as an ephemeral, internet-facing-ish
# build node: no SSH, SSM Session Manager only. IMDSv2 enforcement itself is
# set at the EC2 attribute level (packer/sources.pkr.hcl metadata_options and
# the Terraform launch template), not in the OS.
set -euo pipefail

# The AMI never listens on SSH. Access is via SSM Session Manager, which
# amazon-ssm-agent (enabled in 10-install-base-packages.sh) provides without
# any inbound security group rule. `disable` (not `stop`) so the current
# Packer-over-SSH provisioning connection is left intact.
systemctl disable sshd.service || true

# Defense in depth in case an operator re-enables sshd on a running instance.
sed -i \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
  -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
  -e 's/^#\?X11Forwarding.*/X11Forwarding no/' \
  -e 's/^#\?AllowTcpForwarding.*/AllowTcpForwarding no/' \
  /etc/ssh/sshd_config

# Make sure the SSM agent (our only remote access path) is enabled.
systemctl enable amazon-ssm-agent

# Runner home / work directories must not be group/world-writable.
chmod 0750 /home/runner
chmod 0750 /opt/actions-runner
