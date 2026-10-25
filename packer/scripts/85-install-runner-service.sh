#!/usr/bin/env bash
# Installs the systemd unit, runner lifecycle scripts, and Docker daemon
# config staged by the Packer file provisioner at /tmp/packer-files.
#
# The unit is intentionally NOT enabled here: it depends on
# /etc/github-runner/runner.env, which does not exist until Terraform's
# user_data writes it at boot (see terraform/modules/github-runner-asg).
# user_data runs `systemctl start github-runner.service` explicitly once
# that file is in place, avoiding a race with systemd's normal boot order.
set -euo pipefail

staging=/tmp/packer-files

install -d -m 0755 /opt/github-runner/bin
install -m 0755 "${staging}/scripts/runner-register.sh" /opt/github-runner/bin/runner-register.sh
install -m 0755 "${staging}/scripts/runner-start.sh" /opt/github-runner/bin/runner-start.sh
install -m 0755 "${staging}/scripts/runner-cleanup.sh" /opt/github-runner/bin/runner-cleanup.sh
install -m 0755 "${staging}/scripts/fetch-runner-token.sh" /opt/github-runner/bin/fetch-runner-token.sh

install -d -m 0755 /etc/github-runner

install -m 0644 "${staging}/systemd/github-runner.service" /etc/systemd/system/github-runner.service
systemctl daemon-reload

install -d -m 0755 /etc/docker
install -m 0644 "${staging}/docker/daemon.json" /etc/docker/daemon.json
